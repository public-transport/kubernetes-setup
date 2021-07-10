#!/usr/bin/env node

const {
	getInput,
	debug, info,
	startGroup, endGroup,
	setFailed,
} = require('@actions/core')
const last = require('lodash/last')
const {exec} = require('@actions/exec')
const glob = require('@actions/glob')
const {readFileSync, writeFileSync} = require('fs')
const {join: pJoin} = require('path')

const {
	GITHUB_REPOSITORY,
	GITHUB_ACTOR,
	GITHUB_REF,
	GITHUB_SHA,
	GITHUB_WORKSPACE,
} = process.env
const [GITHUB_ORG, GITHUB_REPO] = GITHUB_REPOSITORY.split('/')
const COMMIT = GITHUB_SHA.slice(0, 7)
const DIR = GITHUB_WORKSPACE

const buildDockerImage = async (dockerRepo, dockerTag) => {
	const tag = 'publictransport/' + dockerRepo + ':' + dockerTag
	await exec('docker', ['build', '-t', tag, '--iidfile', '/tmp/iid.txt', '.'])
	const hash = await readFileSync('/tmp/iid.txt', { encoding: 'utf8' })

	return {tag, hash}
}

const pushImageToHub = async (user, token, tag, hash) => {
	await exec('docker', ['login', '-u', user, '--password-stdin'], {
		input: token,
	})
	await exec('docker', ['push', tag])

	let rawId = ''
	await exec('docker', ['image', 'inspect', hash, '-f', '{{index .RepoDigests 0}}'], {
		listeners: {
			stdout: data => { rawId += (data.toString()) }
		}
	})
	const id = rawId.replace(/\s/gi, '')
	info('Docker image ID: ' + id) // todo: debug-level

	return id
}

const deployToK8s = async (kubeconfig, imageId) => {
	const pKubecfg = pJoin(DIR, '.kubeconfig')
	await writeFileSync(pKubecfg, kubeconfig)

	const deploymentResources = []
	const globber = await glob.create(pJoin(DIR, 'kubernetes/**/*.yaml'))
	for await (const resource of globber.globGenerator()) {
		// replace image placeholder
		debug(`replacing image placeholder for "${resource}"`)
		await exec('sed', ['-e', `s|<IMAGE>|${imageId}|`, '-i', resource])

		// apply resource definition
		debug(`applying resource definition for "${resource}"`)
		await exec('kubectl', ['--kubeconfig', pKubecfg, 'apply', '-f', resource])

		// read api kind (check if resource is a deployment)
		let apiKind = ''
		await exec('kubectl', ['--kubeconfig', pKubecfg, 'get', '-f', resource, '-o', 'jsonpath={.kind}'], {
			listeners: {
				stdout: data => { apiKind += (data.toString()) }
			}
		})
		debug(`checking api kind for "${resource}": "${apiKind}"`)
		if (apiKind.toLowerCase() === 'deployment') deploymentResources.push(resource)
	}

	for (const resource of deploymentResources) {
		// verify rollout status for deployments
		debug(`verifying rollout status for "${resource}"`)
		await exec('kubectl', ['--kubeconfig', pKubecfg, 'rollout', 'status', '-f', resource, '--timeout', '2m'])
	}
}

;(async () => {
	const dockerUser = getInput('docker-user') || GITHUB_ACTOR
	debug('Docker Hub user: ' + dockerUser)
	const dockerToken = getInput('docker-access-token', {required: true})
	const dockerRepo = getInput('docker-repo') || GITHUB_REPO
	debug('Docker Hub repo: ' + dockerRepo)
	const dockerTag = GITHUB_REF ? last(GITHUB_REF.split('/')) : COMMIT
	debug('Docker Hub tag: ' + dockerTag)

	const _kubeconfig = getInput('kubernetes-config', {required: true})
	const kubeconfig = Buffer.from(_kubeconfig, 'base64').toString('utf8')
	debug('kubeconfig', kubeconfig.slice(0, 20)) // todo: remove

	startGroup('build Docker image')
	const {
		tag: imageTag,
		hash: imageHash
	} = await buildDockerImage(dockerRepo, dockerTag)
	endGroup()

	startGroup('push image to the publictransport org')
	const imageId = await pushImageToHub(dockerUser, dockerToken, imageTag, imageHash)
	endGroup()

	startGroup('deploy to Kubernetes')
	await deployToK8s(kubeconfig, imageId)
	endGroup()
})()
.catch((err) => {
	console.error(err)
	setFailed(err && err.message || (err + ''))
	process.exit(1)
})

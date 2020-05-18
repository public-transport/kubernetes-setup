#!/usr/bin/env node

const {
	getInput,
	debug, info,
	startGroup, endGroup,
	setFailed,
} = require('@actions/core')
const last = require('lodash/last')
const {exec} = require('@actions/exec')
const {readFileSync, writeFileSync} = require('fs')
const {join: pJoin} = require('path')
const {parseAllDocuments: parseYaml} = require('yaml')

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
    const hash = await readFileSync('/tmp/iid.txt', {encoding: 'utf8'})
    const id = 'publictransport/' + dockerRepo + '@' + hash
    info('Docker image ID: ' + id) // todo: debug-level

    return {tag, hash, id}
}

const pushImageToHub = async (user, token, tag) => {
    await exec('docker', ['login', '-u', user, '--password-stdin'], {
    	input: token,
    })
    await exec('docker', ['push', tag])
}

const _k8sMapGet = (map, key) => {
	for (const item of map.items) {
		if (item.type !== 'PAIR') continue
		if (item.key.value === key) return item.value
	}
	return null
}

const deployToK8s = async (kubeconfig, imageId) => {
    const rawSvc = readFileSync(pJoin(DIR, 'kubernetes.yaml'), {encoding: 'utf8'})
    const svc = rawSvc.replace('<IMAGE>', imageId)

    const objects = parseYaml(svc).map(doc => doc.contents)
    const deployment = objects.find((obj) => {
    	const v = _k8sMapGet(obj, 'apiVersion')
    	const k = _k8sMapGet(obj, 'kind')
		return (
			v && v.value === 'apps/v1' &&
			k && k.value === 'Deployment'
		)
    })
    if (!deployment) throw new Error('k8s Deployment not found')
    const metadata = _k8sMapGet(deployment, 'metadata')
    if (!metadata) throw new Error('invalid k8s Deployment')
    const name = _k8sMapGet(metadata, 'name').value
	debug('Kubernetes Deployment name: ' + name)
    const ns = _k8sMapGet(metadata, 'namespace').value
	debug('Kubernetes Deployment namespace: ' + ns)

    const pKubecfg = pJoin(DIR, '.kubeconfig')
    await writeFileSync(pKubecfg, kubeconfig)
    await exec('kubectl', ['--kubeconfig', pKubecfg, 'apply', '-f', '-'], {
    	input: svc,
    })
    // todo: de-hardcode deployment & namespace name
    await exec('kubectl', ['--kubeconfig', pKubecfg, 'rollout', 'status', 'deployment/' + name, '--namespace', ns, '--timeout', '2m'])
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
		id: imageId,
	} = await buildDockerImage(dockerRepo, dockerTag)
	endGroup()

	startGroup('push image to the publictransport org')
	await pushImageToHub(dockerUser, dockerToken, imageTag)
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

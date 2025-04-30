yaml_check() {
	FILE="${1}"

	py=$(
		cat <<EOF
import yaml, sys

def path(loader, tag_suffix, node):
  tags = [u'!include-raw-expand:', u'!include:', u'!include-raw-verbatim:']
  if tag_suffix not in tags:
    raise Exception('unknown tag: {}, expected: {}'.format(tag_suffix, tags))
  return 'input-raw'

yaml.add_multi_constructor('', path)
yaml.load(sys.stdin, Loader=yaml.Loader)
EOF
	)

	OUT=$(python3 -c "${py}" 2>&1 <"${FILE}" || true)
	if [ -n "${OUT}" ]; then
		echo ""
		echo "$(red 'Found some issues:')"
		echo "${OUT}"
		exit 1
	fi
}

run_yaml_check() {
	FILES="${2}"

	echo "$FILES" | while IFS= read -r line; do yaml_check "${line}"; done
}

run_yaml_deadcode() {
	OUT=$(
		go run tests/suites/static_analysis/deadcode/main.go "$(pwd)" <<EOF 2>&1 || true
files:
  skip:
    - .github/workflows/static-analysis.yml
    - .github/workflows/local-deployment.yml
    - yamlfmt.yaml
jobs:
  ignore:
    - build-dqlite
    - build-musl
    - ci-trigger-github-com-juju-juju
    - ci-build-juju
    - ci-gating-tests
    - clean-workspaces
    - run-build-check-lxd
    - github-juju-check-jobs
    - github-juju-merge-jobs
    - github-juju-pylibjuju-jobs
    - github-integration-tests-pylibjuju
    - github-mgo-check-jobs
    - github-mgo-merge-jobs
    - github-prs
    - sync-ntp
    - z-clean-resources-azure
    - z-clean-resources-aws
    - z-clean-resources-gce
    - z-clean-resources-gke
    - z-clean-resources-aks
    - z-clean-resources-vsphere
    - z-clean-resources-eks
    - z-clean-resources-ecr
    - upload-s3-agent-binaries
    - unit-tests-s390x
    - unit-tests-race-arm64
    - unit-tests-ppc64el
    - unit-tests-arm64
    - make-windows-installer
    - gating-functional-tests-s390x
    - gating-functional-tests-ppc64el
    - test-refresh-multijob
    - build-jujud-operator-test
    - analyse-juju-tics
    - build-juju-jobs
EOF
	)
	if [ -n "${OUT}" ]; then
		echo ""
		echo "$(red 'Found some issues:')"
		echo "${OUT}"
		exit 1
	fi
}

run_yaml_simplify() {
	OUT=$(
		go run tests/suites/static_analysis/simplify/main.go "$(pwd)" <<EOF 2>&1 || true
files:
  skip:
    - .github/workflows/static-analysis.yml
    - .github/workflows/local-deployment.yml
    - jobs/ci-run/integration/gen/*
    - yamlfmt.yaml
jobs:
  ignore:
    - build-dqlite:build-dqlite-runner
    - build-musl:build-musl-runner
    # TODO (stickupkid): Clean these commands up and simplify the following jobs
    # so that they don't require a multi-job for no reason.
    - ci-build-juju:Packaging
    - github-mgo-check-jobs:github-mgo-check-jobs
    - github-mgo-merge-jobs:github-mgo-merge-jobs
    - github-juju-merge-jobs:github-juju-merge-jobs
    - github-juju-merge-jobs-{job_suffix}:github-juju-merge-jobs
    - github-juju-pylibjuju-jobs:github-juju-pylibjuju-jobs
    - github-juju-check-jobs:github-juju-check-jobs
    - test-bootstrap-multijob:IntegrationTests-bootstrap
    - test-coslite-multijob:IntegrationTests-cloud_azure
    - test-coslite-multijob:IntegrationTests-coslite
    - test-deploy_aks-multijob:IntegrationTests-deploy_aks
    - test-deploy_caas-multijob:IntegrationTests-deploy_caas
    - test-expose_ec2-multijob:IntegrationTests-expose_ec2
    - test-upgrade-multijob:IntegrationTests-upgrade
    - test-upgrade_series-multijob:IntegrationTests-upgrade_series
    - test-secrets_k8s-multijob:IntegrationTests-secrets_k8s
    - test-secrets_iaas-multijob:IntegrationTests-secrets_iaas
EOF
	)
	if [ -n "${OUT}" ]; then
		echo ""
		echo "$(red 'Found some issues:')"
		echo "${OUT}"
		exit 1
	fi
}

run_yaml_alphabetise() {
	OUT=$(
		go run tests/suites/static_analysis/alphabetise/main.go "$(pwd)" <<EOF 2>&1 || true
files:
  skip:
    - .github/workflows/static-analysis.yml
    - .github/workflows/local-deployment.yml
    - yamlfmt.yaml
jobs:
  ignore: []
EOF
	)
	if [ -n "${OUT}" ]; then
		echo ""
		echo "$(red 'Found some issues:')"
		echo "${OUT}"
		exit 1
	fi

}

test_static_analysis_yaml() {
	if [ "$(skip 'test_static_analysis_yaml')" ]; then
		echo "==> TEST SKIPPED: static yaml analysis"
		return
	fi

	(
		set_verbosity

		cd .. || exit

		FILES=$(find ./* -name '*.yml')

		go mod download

		# YAML static analysis
		if which python >/dev/null 2>&1; then
			run "run_yaml_check" "${FILES}"
		else
			echo "python not found, yaml static analysis disabled"
		fi

		# YAML deadcode elimiation
		if which go >/dev/null 2>&1; then
			run "run_yaml_deadcode"
		else
			echo "go not found, yaml deadcode disabled"
		fi

		# YAML simplify
		if which go >/dev/null 2>&1; then
			run "run_yaml_simplify"
		else
			echo "go not found, yaml simplify disabled"
		fi

		# YAML alphabetise
		if which go >/dev/null 2>&1; then
			run "run_yaml_alphabetise"
		else
			echo "go not found, yaml alphabetise disabled"
		fi
	)
}

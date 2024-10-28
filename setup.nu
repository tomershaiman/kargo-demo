#!/usr/bin/env nu

rm --force .env

source scripts/kubernetes.nu
source scripts/ingress.nu
source scripts/cert-manager.nu

mut github_org = ""
if GITHUB_ORG in $env {
    $github_org = $env.GITHUB_ORG
} else {
    $github_org = input $"(ansi green_bold)Enter GitHub private access token: (ansi reset)"
}
$"export GITHUB_ORG=($github_org)\n"
    | save --append .env

let github_repo_url = $"https://github.com/($github_org)/kargo-demo"
$"export GITHUB_REPO_URL=($github_repo_url)\n"
    | save --append .env

mut github_pat = ""
if GITHUB_PAT in $env {
    $github_pat = $env.GITHUB_PAT
} else {
    $github_pat = input $"(ansi green_bold)Enter GitHub private access token: (ansi reset)" --suppress-output
}
$"export GITHUB_PAT=($github_pat)\n"
    | save --append .env

mut github_username = ""
if GITHUB_USERNAME in $env {
    $github_username = $env.GITHUB_USERNAME
} else {
    $github_username = input $"(ansi green_bold)Enter GitHub username: (ansi reset)" --suppress-output
}
$"export GITHUB_USERNAME=($github_username)\n"
    | save --append .env

create_kubernetes kind

let ingress_data = apply_ingress kind nginx

apply_certmanager

(
    helm upgrade --install argocd argo-cd
        --repo https://argoproj.github.io/argo-helm
        --namespace argocd --create-namespace
        --values argocd-values.yaml --wait
)

(
    helm upgrade --install argo-rollouts argo-rollouts
        --repo https://argoproj.github.io/argo-helm
        --create-namespace --namespace argo-rollouts --wait
)

(
    helm upgrade --install kargo
        oci://ghcr.io/akuity/kargo-charts/kargo
        --namespace kargo --create-namespace
        --values kargo-values.yaml --wait
)

open application-set.yaml
    | upsert spec.template.spec.source.repoURL $github_repo_url
    | save application-set.yaml --force

for environment in ["dev", "pre-prod", "prod"] {
    open $"kargo-manifests/stage-($environment).yaml"
        | upsert spec.promotionTemplate.spec.steps.0.config.repoURL $github_repo_url
        | upsert spec.promotionTemplate.spec.steps.6.config.apps.0.sources.0.repoURL $github_repo_url
        | save $"kargo-manifests/stage-($environment).yaml" --force
}

do --ignore-errors {
    git add .
    git commit -m "Customization"
    git push
}

print $"
Install (ansi green_bold)kargo CLI(ansi reset) from https://docs.kargo.io/quickstart#installing-the-kargo-cli.
Press (ansi green_bold)any key(ansi reset) to continue."
    input
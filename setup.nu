#!/usr/bin/env nu

source scripts/kubernetes.nu
source scripts/ingress.nu
source scripts/cert-manager.nu

create_kubernetes kind

let ingress_data = apply_ingress kind nginx

apply_certmanager

(
    helm upgrade --install argocd argo-cd
        --repo https://argoproj.github.io/argo-helm
        --namespace argocd --create-namespace
        --set 'configs.secret.argocdServerAdminPassword=$2a$10$5vm8wXaSdbuff0m9l21JdevzXBzJFPCi8sy6OOnpZMAG.fOXL7jvO'
        --set dex.enabled=false
        --set notifications.enabled=false
        --set server.service.type=NodePort
        --set server.service.nodePortHttp=31443
        --set server.extensions.enabled=true
        --set 'server.extensions.contents[0].name=argo-rollouts'
        --set 'server.extensions.contents[0].url=https://github.com/argoproj-labs/rollout-extension/releases/download/v0.3.3/extension.tar'
        --wait
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
        --set api.service.type=NodePort
        --set api.service.nodePort=31444
        --set api.adminAccount.passwordHash='$2a$10$Zrhhie4vLz5ygtVSaif6o.qN36jgs6vjtMBdM6yrU1FOeiAAMMxOm'
        --set api.adminAccount.tokenSigningKey=iwishtowashmyirishwristwatch
        --wait
)

let github_username = input $"(ansi green_bold)Enter GitHub username: (ansi reset)"
$"export GITHUB_USERNAME=($github_username)\n"
    | save --append .env

let github_repo_url = $"https://github.com/($github_username)/kargo-demo"
$"export GITHBU_REPO_URL=($github_repo_url)\n"
    | save --append .env

mut github_pat = ""
if GITHUB_PAT in $env {
    $github_pat = $env.GITHUB_PAT
} else {
    $github_pat = input $"(ansi green_bold)Enter GitHub private access token: (ansi reset)" --suppress-output
}
$"export GITHUB_PAT=($github_pat)\n"
    | save --append .env

open application-set.yaml
    | upsert spec.template.spec.source.repoURL $github_repo_url
    | save application-set.yaml --force

for environment in ["test", "uat", "prod"] {
    open $"kargo/stage-($environment).yaml"
        | upsert spec.promotionTemplate.spec.steps.0.config.repoURL $github_repo_url
        | upsert spec.promotionTemplate.spec.steps.6.config.apps.0.sources.0.repoURL $github_repo_url
        | save $"kargo/stage-($environment).yaml" --force
}

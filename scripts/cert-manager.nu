#!/usr/bin/env nu

def apply_certmanager [] {

    (
        helm upgrade --install cert-manager cert-manager
            --repo https://charts.jetstack.io
            --namespace cert-manager --create-namespace
            --set crds.enabled=true --wait
    )

}
#!/usr/bin/env nu

def apply_ingress [provider: string, type = "traefik"] {

    if $type == "traefik" {

        (
            helm upgrade --install traefik traefik
                --repo https://helm.traefik.io/traefik
                --namespace traefik --create-namespace --wait
        )
    
    } else if $type == "nginx" {

        if $provider == "kind" {

            (
                kubectl apply
                    --filename https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
            )

            sleep 10sec

            (
                kubectl --namespace ingress-nginx wait
                    --for=condition=Available
                    deployment ingress-nginx-controller
            )

        }

    } else {

        print $"(ansi red_bold)($type)(ansi reset) is not a supported."
        exit 1

    }

    mut ingress_ip = ""

    
    if $provider == "aws" {

        sleep 10sec

        let ingress_hostname = (
            kubectl --namespace traefik
                get service traefik --output yaml
                | from yaml
                | get status.loadBalancer.ingress.0.hostname
        )

        while $ingress_ip == "" {
            print "Waiting for Ingress Service IP..."
            sleep 10sec
            $ingress_ip = (dig +short $ingress_hostname)
        }

    } else if $provider == "kind" {

        $ingress_ip = "127.0.0.1"

    } else {

        while $ingress_ip == "" {
            print "Waiting for Ingress Service IP..."
            sleep 10sec
            $ingress_ip = (
                kubectl --namespace traefik
                    get service traefik --output yaml
                    | from yaml
                    | get status.loadBalancer.ingress.0.ip
            )
        }
    }

    $ingress_ip = $ingress_ip | lines | first

    $"export INGRESS_IP=($ingress_ip)\n" | save --append .env
    $"export INGRESS_HOST=($ingress_ip).nip.io\n" | save --append .env

    {ip: $ingress_ip, host: $"($ingress_ip).nip.io", class: $type}

}

template = 'defaultPipeline'

libraries {
    git
    docker
    maven
    argocd
    terraform
}

global_vars {
    APP_NAME = "MyApp"
    ENVIRONMENT = "dev"
}

pipeline_settings {
    enforce_scm = true
}

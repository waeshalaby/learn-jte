#!/bin/bash

# Define the repository name
JTE_REPO="jenkins-jte-repo"

# Set default libraries if not provided as an argument
DEFAULT_LIBS="git docker maven argocd terraform"
LIBRARIES=${1:-$DEFAULT_LIBS}  # Use input or default libraries

# Create the main repository and required directories
mkdir -p $JTE_REPO/{templates,libraries}

# Create directories for each library
for LIB in $LIBRARIES; do
    mkdir -p $JTE_REPO/libraries/$LIB/{resources,steps}
done

# Create the JTE pipeline configuration file
cat <<EOF > $JTE_REPO/pipeline_config.groovy
template = 'defaultPipeline'

libraries {
$(for LIB in $LIBRARIES; do echo "    $LIB"; done)
}

global_vars {
    APP_NAME = "MyApp"
    ENVIRONMENT = "dev"
}

pipeline_settings {
    enforce_scm = true
}
EOF

# Create a default pipeline template
cat <<EOF > $JTE_REPO/templates/defaultPipeline.jenkinsfile
pipeline {
    agent any
    environment {
        APP_NAME = globalVars.APP_NAME
        ENVIRONMENT = globalVars.ENVIRONMENT
    }
    stages {
        stage('Checkout') {
            steps {
                gitCheckout()
            }
        }
        stage('Build') {
            steps {
                buildImage()
            }
        }
        stage('Deploy') {
            steps {
                deployApp()
            }
        }
        stage('Infra Setup') {
            steps {
                deployTerraform(region: 'us-east-1', workspace: 'production')
            }
        }
    }
}
EOF

# Create _init.groovy files for each library
for LIB in $LIBRARIES; do
    LIB_CAPITALIZED=$(echo "$LIB" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')

    cat <<EOF > $JTE_REPO/libraries/$LIB/_init.groovy
println "${LIB_CAPITALIZED} Library Loaded!"
EOF
done

# Create step files for each library
if [[ $LIBRARIES == *"git"* ]]; then
    cat <<EOF > $JTE_REPO/libraries/git/steps/gitCheckout.groovy
void call() {
    checkout scm
}
EOF
fi

if [[ $LIBRARIES == *"docker"* ]]; then
    cat <<EOF > $JTE_REPO/libraries/docker/steps/buildImage.groovy
void call() {
    sh 'docker build -t my-app:latest .'
}
EOF
fi

if [[ $LIBRARIES == *"maven"* ]]; then
    cat <<EOF > $JTE_REPO/libraries/maven/steps/buildMavenProject.groovy
void call() {
    sh 'mvn clean package'
}
EOF

    # Create a sample static resource file for Maven
    cat <<EOF > $JTE_REPO/libraries/maven/resources/settings.xml
<settings>
  <mirrors>
    <mirror>
      <id>central</id>
      <mirrorOf>*</mirrorOf>
      <url>https://repo.maven.apache.org/maven2</url>
      <layout>default</layout>
    </mirror>
  </mirrors>
</settings>
EOF
fi

if [[ $LIBRARIES == *"argocd"* ]]; then
    cat <<EOF > $JTE_REPO/libraries/argocd/steps/deployApp.groovy
void call() {
    def appManifest = libraryResource 'argocd/application.yaml'
    writeFile file: 'application.yaml', text: appManifest
    sh 'kubectl apply -f application.yaml'
}
EOF

    # Create a sample Kubernetes ArgoCD application file
    cat <<EOF > $JTE_REPO/libraries/argocd/resources/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  destination:
    namespace: my-app
    server: https://kubernetes.default.svc
  source:
    path: my-app/
    repoURL: https://github.com/my-org/my-app.git
    targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
fi

# Add a library with more logic: Terraform (last library)
if [[ $LIBRARIES == *"terraform"* ]]; then
    cat <<EOF > $JTE_REPO/libraries/terraform/steps/deployTerraform.groovy
void call(Map params) {
    def region = params.getOrDefault('region', 'us-west-2')
    def workspace = params.getOrDefault('workspace', 'default')

    echo "Initializing Terraform in \${region} with workspace \${workspace}"
    sh "terraform init"
    sh "terraform workspace select \${workspace} || terraform workspace new \${workspace}"
    sh "terraform apply -auto-approve"
}
EOF

    # Create a Terraform resource file
    cat <<EOF > $JTE_REPO/libraries/terraform/resources/main.tf
provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-jte-terraform-bucket"
  acl    = "private"
}
EOF
fi

echo "✅ JTE Repository Initialized at $JTE_REPO with libraries: $LIBRARIES"


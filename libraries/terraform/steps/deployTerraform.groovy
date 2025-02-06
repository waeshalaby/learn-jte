void call(Map params) {
    def region = params.getOrDefault('region', 'us-west-2')
    def workspace = params.getOrDefault('workspace', 'default')

    echo "Initializing Terraform in ${region} with workspace ${workspace}"
    sh "terraform init"
    sh "terraform workspace select ${workspace} || terraform workspace new ${workspace}"
    sh "terraform apply -auto-approve"
}

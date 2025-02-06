void call() {
    def appManifest = libraryResource 'argocd/application.yaml'
    writeFile file: 'application.yaml', text: appManifest
    sh 'kubectl apply -f application.yaml'
}

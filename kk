# Deploy to Azure Kubernetes Service
# Build and push image to Azure Container Registry; Deploy to Azure Kubernetes Service
# https://docs.microsoft.com/azure/devops/pipelines/languages/docker

trigger:
- master

resources:
- repo: self

variables:

  # Container registry service connection established during pipeline creation
  dockerRegistryServiceConnection: '47d55b71-eb65-42c2-8f56-cb506da20af6'
  imageRepository: 'crdawakoplatform.azurecr.io/app1/app1nginx'
  containerRegistry: 'crdawakoplatform.azurecr.io'
  dockerfilePath: '$(Build.SourcesDirectory)/Dockerfile'
  tag: '$(Build.BuildId)'
  imagePullSecret: 'crdawakoplatform17309a7f-auth'

  # Agent VM image name
  vmImageName: 'ubuntu-latest'


stages:
- stage: Build
  displayName: Build and push stage
  jobs:  
  - job: Build
    displayName: Build
    pool:
      vmImage: $(vmImageName)
    steps:
    - task: Docker@2
      displayName: Build and push an image to container registry
      inputs:
        command: buildAndPush
        repository: $(imageRepository)
        dockerfile: $(dockerfilePath)
        containerRegistry: $(dockerRegistryServiceConnection)
        tags: |
          $(tag)
## Publish Artifacts pipeline code in addition to Build and Push          
    - bash: echo Contents in System Default Working Directory; ls -R $(System.DefaultWorkingDirectory)        
    - bash: echo Before copying Contents in Build Artifact Directory; ls -R $(Build.ArtifactStagingDirectory)        
    # Task-2: Copy files (Copy files from a source folder to target folder)
    # Source Directory: $(System.DefaultWorkingDirectory)/kube-manifests
    # Target Directory: $(Build.ArtifactStagingDirectory)
    - task: CopyFiles@2
      inputs:
        SourceFolder: '$(System.DefaultWorkingDirectory)/kube-manifests'
        Contents: '**'
        TargetFolder: '$(Build.ArtifactStagingDirectory)'
        OverWrite: true
    # List files from Build Artifact Staging Directory - After Copy
    - bash: echo After copying to Build Artifact Directory; ls -R $(Build.ArtifactStagingDirectory)  
    # Task-3: Publish build artifacts (Publish build to Azure Pipelines)           
    - task: PublishBuildArtifacts@1
      inputs:
        PathtoPublish: '$(Build.ArtifactStagingDirectory)'
        ArtifactName: 'kube-manifests'
        publishLocation: 'Container'
        
- stage: Deploy
  displayName: Deploy stage
  dependsOn: Build

  jobs:
  - deployment: Deploy
    displayName: Deploy
    pool:
      vmImage: $(vmImageName)
    environment: 'wmoinarazuredevopsgithubacraksapp1-7268.default'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: KubernetesManifest@0
            displayName: Create imagePullSecret
            inputs:
              action: createSecret
              secretName: $(imagePullSecret)
              dockerRegistryEndpoint: $(dockerRegistryServiceConnection)

          - task: KubernetesManifest@0
            displayName: Deploy to Kubernetes cluster
            inputs:
              action: deploy
              manifests: |
                $(Pipeline.Workspace)/kube-manifests/deployment.yml
                $(Pipeline.Workspace)/kube-manifests/service.yml
              imagePullSecrets: |
                $(imagePullSecret)
              containers: |
                $(containerRegistry)/$(imageRepository):$(tag)

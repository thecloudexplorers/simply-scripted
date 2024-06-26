# Decorator examples

This folder contains examples of [Azure DevOps pipeline decorators](https://learn.microsoft.com/en-us/azure/devops/extend/develop/add-pipeline-decorator?view=azure-devops). For more information on this topic check out the blog post [I am in your pipeline decorating it with compliance]() on [devjev.nl](https://www.devjev.nl/).
The examples mentioned next are available. Each example consist from a `vss-extension.json` and a .yml file as it is assumed that the rest of the required scaffolding is already in place.

## Powershell Hello World Basic

A simple example that injects a PowerShell task that writes `Hello World` into a pipeline every time a pipeline is executed.

## Powershell Hello World Advanced

An example that injects a PowerShell task that writes `Hello World` into a pipeline after a Bash task.

## Microsoft Security DevOps Basic

A simple example that always injects the [Microsoft Security DevOps](https://learn.microsoft.com/en-us/azure/defender-for-cloud/azure-devops-extension) task into all pipelines.

## Microsoft Security DevOps Advanced

A n example that injects the [Microsoft Security DevOps](https://learn.microsoft.com/en-us/azure/defender-for-cloud/azure-devops-extension) task into all pipelines only if the task is not already part of the pipeline.

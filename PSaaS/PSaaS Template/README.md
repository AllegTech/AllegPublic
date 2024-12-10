# Powershell-as-a-Service Template

This is a template to be used to deploy powershell as a service.

To start a new project:
1. Copy the folder
2. Rename folder and files.
3. Adjust to your needs.

## Components

* wrapper.ps1 - Run on the target machine.  Contains a continuous loop that executes code in the module.  Scheduling and/or cadence is handled here.
* code.psm1 - The logic and tasks required by the project.  Is executed on a configurable schedule by wrapper.ps1.
* exampleLocalConfig.json - Contains deployment-specific details required by the project, like customer name.  Will be generated on the machine by the deployment process.
* service.exe - Used to turn wrapper.ps1 into a windows service (WinSW from https://github.com/winsw/winsw/tree/v3)
* service.xml - Config file for service.exe.  Defines service name, description, etc...
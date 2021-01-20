# OpenShift Scripts

A set of scripts to help you configure and maintain your local and production OpenShift projects.

Supports both json and yaml based OpenShift configuration templates.

## Environment Setup

1. Clone this repository to your local machine.
1. Install [jq](https://stedolan.github.io/jq/).  [jq](https://stedolan.github.io/jq/) is used by some of the scripts to manipulate the configuration files in preparation for update/replace operations.  The recommended approach is to use either [Homebrew](https://brew.sh/) (MAC) or [Chocolatey](https://chocolatey.org/) (Windows) to install the required packages.
      - Windows:
        - `chocolatey install jq`
      - MAC:
        - `brew install jq`
      - CentOS:
        - `yum install jq`
      - Debian/Ubuntu:
        - `apt install jq`

1. Update your path to include a reference to the `bin` directory

    Using GIT Bash on Windows as an example;
    1. Create a `.bashrc` file in your home directory (`C:\Users\<UserName/>`, for example `C:\Users\Wade`).
    1. Add the line `PATH=${PATH}:/c/openshift-developer-tools/bin`
    1. Restart GIT Bash.  _If you have not done this before, GIT will write out some warnings and create some files for you that fix the issues._

All of the scripts will be available on the path and can be run from any directory.  This is important as many of the scripts expect to be run from the top level `./openshift` directory you will create in your project.

### MAC Setup

These scripts use `sed` and regular expression processing.  The default version of `sed` on MAC does support some of the processing.  Details can be found here; [Differences between sed on Mac OSX and other "standard" sed?](https://unix.stackexchange.com/questions/13711/differences-between-sed-on-mac-osx-and-other-standard-sed)

Update your path to have this repo's bin folder in it.  You may need to alter the paths in the command below to reflect wherever you cloned your fork to.  Append this line to your `~\.bashrc` file:

```
[[ ":$PATH:" != *"/openshift-developer-tools/bin:"* ]] && export PATH="~/openshift-developer-tools/bin:$PATH"
```

Please install `gnu-sed`.

Using [Homebrew](https://brew.sh):

```
brew install gnu-sed
```

Then update your path and prepend `/usr/local/opt/gnu-sed/libexec/gnubin:` to your existing path so that the system defaults to using `sed` rather than `gsed`.  Append this line to your `~\.bashrc` file:

```
[[ ":$PATH:" != *"/usr/local/opt/gnu-sed/libexec/gnubin:"* ]] && export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
```

Similarly, you must install GNU find:

```
brew install findutils
```

Then update your path and prepend `/usr/local/opt/findutils/libexec/gnubin:` to your existing path so that the system defaults to using `find` rather than `gfind`.  Append this line to your `~\.bashrc` file:

```
[[ ":$PATH:" != *"/usr/local/opt/findutils/libexec/gnubin:"* ]] && export PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
```


Also make sure `usr/local/bin` is at a higher priority on your **PATH** than `usr/bin`.  You can do this by making sure `usr/local/bin` is to the left of `usr/bin`, preceding it in the **PATH** string.  This will ensure that packages installed by Homebrew override system binaries; in this case `sed`.  Append this line to your `~\.bashrc` file:

```
[[ ":$PATH:" != *"/usr/local/bin:"* ]] && export PATH="/usr/local/bin:$PATH"
```


`brew doctor` can help diagnose such issues.


### Linux Setup

These scripts use `awk`, but problems may be encountered if `mawk` is used rather than the GNU awk `gawk`. `mawk` is used by default in Ubuntu 20.04 and Kali Linux for the Linux Subsystem for Windows.

```
$ awk -W version
mawk 1.3.3 Nov 1996, Copyright (C) Michael D. Brennan
```

For Ubuntu and Kali Linux, installing `gawk` will make it the default implementation of `awk`:

```
$ sudo apt-get install gawk
[... etc ...]

$ awk -W version
GNU Awk 4.2.1, API: 2.0 (GNU MPFR 4.0.2, GNU MP 6.1.2)
```

## Project Structure

To use these scripts your project structure should be organized in one of two ways; split out by component, or simplified.  The one you choose should be based on the complexity of your project and your personal development preferences.

Regardless of which you choose, you will always have a top level `./openshift` directory in your project where you keep your main project settings (`settings.sh`) file.

### Component Project Structure

[TheOrgBook](https://github.com/bcgov/TheOrgBook) and [Family-Protection-Order](https://github.com/bcgov/Family-Protection-Order) are examples of the Component Project Structure.

In general terms the structure looks like this, where the code and the openshift templates for the components are separated out into logical bits.

RootProjectDir
- openshift
- component1
  - openshift
    - templates
- component2
  - openshift
    - templates

### Simple Project Structure

[permitify](https://github.com/bcgov/permitify) is an example of the Simple Project Structure.

In general terms the structure looks like this, where all of the openshift templates for the components are grouped together in a central location.

RootProjectDir
- openshift
  - templates

## Settings.sh

You will need to include a `settings.sh` file in your top level `./openshift` directory that contains your project specific settings.

At a minimum this file should contain definitions for your `PROJECT_NAMESPACE`, `GIT_URI`, and `GIT_REF` all of which should be setup to be overridable.

**For Example:**
```
export PROJECT_NAMESPACE=${PROJECT_NAMESPACE:-devex-von-permitify}
export GIT_URI=${GIT_URI:-"https://github.com/bcgov/permitify.git"}
export GIT_REF=${GIT_REF:-"master"}
```

**Full Simple Project Structure Example:**
```
export PROJECT_NAMESPACE=${PROJECT_NAMESPACE:-devex-von-permitify}
export GIT_URI=${GIT_URI:-"https://github.com/bcgov/permitify.git"}
export GIT_REF=${GIT_REF:-"master"}

# The project components
# - They are all contained under the main OpenShift folder.
export components="."

# The builds to be triggered after buildconfigs created (not auto-triggered)
export builds=""

# The images to be tagged after build
export images="permitify"

# The routes for the project
export routes="bc-registries worksafe-bc"
```

**Full Component Project Structure Example:**
```
export PROJECT_NAMESPACE="devex-von"

export GIT_URI="https://github.com/bcgov/TheOrgBook.git"
export GIT_REF="master"

# The templates that should not have their GIT references (uri and ref) over-ridden
# Templates NOT in this list will have they GIT references over-ridden
# with the values of GIT_URI and GIT_REF
export -a skip_git_overrides="schema-spy-build.json solr-base-build.json"

# The project components
export components="tob-db tob-solr tob-api tob-web"

# The builds to be triggered after buildconfigs created (not auto-triggered)
export builds="nginx-runtime angular-builder"

# The images to be tagged after build
export images="angular-on-nginx django solr schema-spy"

# The routes for the project
export routes="angular-on-nginx django solr schema-spy"
```

## Settings.local.sh

You can also have a `settings.local.sh` file in your top level `./openshift` directory that contains any overrides necessary for deploying your project into a local OpenShift environment.

Typically this will simply contain overrides for the `GIT_URI` and `GIT_REF`, for example:
```
export GIT_URI="https://github.com/WadeBarnes/permitify.git"
export GIT_REF="openshift"
```

These overrides come into play when you are generating local param files, and deploying into a local OpenShift environment.

## Setting Profiles

The scripts support setting profiles, which allow you to further manage your settings for different environments or occasions.  Unlike local settings (`settings.local.sh`), settings profiles are something you want to check into your repository.

Settings profiles are loaded between the default settings (`settings.sh`) and the local settings (`settings.local.sh`), allowing you to apply your local settings to your profiles just as you would your default settings.

Settings profiles work exactly like the other settings files.  To define a settings profile you simply have to create a file with the profile name; `settings.<ProfileName>.sh`.  The scripts will automatically detect the profiles and prompt you to either use them or ignore them.

Scripts that support profiles will expose a `-p <profile>` (lower case p) flag to allow you to load a named profile setting, and a `-P` (upper case P) flag it allow you to use you default settings.

Refer to the help (`-h`) output of the scripts for more details.

## Using the Scripts

When using the scripts run them from the command line in the top level `./openshift` directory of your project.

Most, if not all, scripts contain usage information.  Run the script with `-h` to see it.

You will need to install the OC CLI.  Get a recent stable (or the latest) [Openshift Command Line tool](https://github.com/openshift/origin/releases) (oc) and install it by extracting the "oc" executable and placing it somewhere on your path.  You can also install it with several different package managers.

### Starting/Stopping a Local OpenShift Cluster

Use the `oc-cluster-up.sh` script to start a local OpenShift cluster, and `oc-cluster-down.sh` to stop the cluster.

### Creating a Project Set on Your Local Cluster

If you are resetting your environment run the following script.  Give this operation a bit of time to complete before recreating the projects.

```
generateLocalProjects.sh -D
```

Run the following command to create the projects for the local instance. Test and Prod will not likely be used, but are referenced in some of the later scripts:

```
generateLocalProjects.sh
```

### Initialize the projects - add permissions and storage

For all of the commands mentioned here, you can use the "-h" parameter for usage help and options.

```
initOSProjects.sh
```

If you are running locally you will see some "No resources found." messages which can be ignored.

### Generating Parameter Files

You will need to have your OpenShift build and deployment templates in place, along with your Jenkinsfiles defining your pipelines in order to generate the parameter files needed to generate your builds and configurations in OpenShift.  For examples, have a look at the projects referenced in the Project Structure section.

Once your templates and Jenkinsfiles are in place run `genParams.sh` from within your top level `./openshift` directory.

Edit these files as needed for your project.

#### Generate Local Param Files

Run the following script to generate a series of files with the extension ".local.param" in the "openshift" folder in the root of the repository:

```
genParams.sh -l
```

The files have all the parameters from the various templates in the project, with all of the parameters initially set to be commented out.

Edit these files as needed for your project.

### Generate the Build and Images in the "tools" project; Deploy Jenkins

On the command line, change into the "openshift" folder in the root of your repo and run the script:

```
genBuilds.sh -h
```

Review the command line parameters and pass in the appropriate parameters - without the -h.  For an initial install, no parameters are needed.

#### Updating Build and Image Configurations

If you are adding build and image configurations you can re-run this script.  You will encounter errors for any of the resources that already exist, but you can safely ignore these areas and allow the script to continue.

If you are updating build and image configurations use the `-u` option.

If you are adding and updating build and image configurations, run the script **without** the `-u` option first to create the new resources and then again **with** the `-u` option to update the existing configurations.

## Generate the Deployment Configurations and Deploy the Components

On the command line, change into the "openshift" folder in the root of your repo and run the script:

```
genDepls.sh -h
```

Review the command line parameters available and rerun with the appropriate parameters - without the -h. For an initial deploy, no parameters are needed.

#### Updating Deployment Configurations

If you are adding deployment configurations you can re-run this script.  You will encounter errors for any of the resources that already exist, but you can safely ignore these areas and allow the script to continue.

If you are updating deployment configurations use the `-u` option.

If you are adding and updating deployment configurations, run the script **without** the `-u` option first to create the new resources and then again **with** the `-u` option to update the existing configurations.

**_Note;_**

**_Some settings on some resources are immutable.  You will need to delete and recreate the associated resource(s).  Care must be taken with resources containing credentials or other auto-generated resources, however.  You must insure such resources are replaced using the same values._**

**_Updating the deployment configurations can affect (overwrite) auto-generated secrets such as the database username and password._**

## Fixing routes - for local instances

In the current instance of the deployment, the routes created are explicitly defined for the Pathfinder (BC Gov) instance of OpenShift. Run the script to create the default routes for your local environment:

```
updateRoutes.sh
```

# Troubleshooting

## Disk Pressure Issue (MAC and Windows)

If you start seeing builds and deploys failing due to disk pressure issues it's because OpenShift thinks you are running out of disk space and will start evicting pods.

### Docker on Windows

The quick fix is to delete the Moby Linux VM and its associated virtual disk and start again.

### MiniShift

The default settings for minishift create a small VM with very little memory and disk.

The fix is to run the following commands to create a more suitable environment;
```
minishift stop
minishift delete
minishift config set disk-size 60g
minishift config set memory 6GB
minishift start
```

## OpenShift (Docker on MAC)

If you run into certificate errors like `x509: certificate signed by unknown authority` when trying to connect to your local OpenShift cluster from the command line, log into the cluster from the command line using the token login from the web console.
1. Login to the web console.
1. From the **(?)** drop-down select **Command Line Tools**
1. Copy the login command from the console.
1. Paste it onto the command line.
1. You should to prompted to allow insecure connections.
1. Select `yes` and continue.

# Scripts

Following is a list of the top level scripts.  There are additional lower level scripts that are not listed here since they are wrapped into top level scripts.

Use `-h` to get more detailed usage information on the scripts.

## testConnection

A script for testing whether or not one or more host:port combinations are opened or closed.  The script can be used to test connections locally or remotely from within a pod in order to test connectivity from that pod to other services.

Example testing the connectivity from one pod to other pods:
```
$ testConnection -f TestConnections.txt -n devex-von-tools -p angular-on-nginx

Reading list of hosts and ports from TestConnections.txt ...

Testing connections from devex-von-tools/angular-on-nginx ...
google.com:80 - Open
angular-on-nginx:8080 - Closed
django:8080 - Open
postgresql:5432 - Closed
weasyprint:5001 - Closed
schema-spy:8080 - Closed
```

Run `testConnection -h` for additional details.

## dropAndRecreateDatabase.sh

A helper script to drop and recreate the application database within a given environment.

Refer to the usage documentation contained in the script for details.  Run the script without parameters to see the documentation.

_This script could be further enhanced to utilize the environment variables within the running pod to determine various database parameters dynamically.  The process will require some fussing around with escaping quotes and such to get things just right._

## genBuilds.sh

Generate the build configurations for the project.

## genDepls.sh

Generate the deployment configurations for the project.

## generateLocalProjects.sh

Generate a set of OpenShift projects in a local cluster.

## genParams.sh

Generate the parameter files for the OpenShift templates defined in a project.

## initOSProjects.sh

Initializes the permissions and storage services for the OpenShift projects.

## oc-cluster-down.sh

Shutdown your local OpenShift cluster.

## oc-cluster-up.sh

Start your local OpenShift cluster.

## oc-pull-image.sh

Pull an image from an OpenShift project into your local Docker registry.

## oc-push-image.sh

Push an image from your local Docker registry into an OpenShift project.

## runInContainer.sh

This script is a wrapper around `oc exec` that allows you to run commands inside a pod instance based on its general name.

Refer to the usage documentation contained in the script for details.  Run the script without parameters to see the documentation.

## scaleDeployment.sh

A helper script to scale a deployment to a particular number of pods.

## tagProjectImages.sh

Tags the project's images, as defined in the project's settings.sh file.

## updateRoutes.sh

For use with local instances.  Updates the routes, as defined in the project's settings.sh file.

## exportTemplate.sh

Helper script to export an OpenShift resource as a template.

# OpenShift Scripts

A set of scripts to help you configure and maintain your local and production OpenShift projects.

## Environemnt Setup

1. Clone this repository to your local machine.
1. Update your path to include a reference to the `bin` directory

Using GIT Bash on Windows as an example;
1. Create a `.bashrc` file in your home directory (`C:\Users\<UserName/>`, for ewxample `C:\Users\Wade`).
1. Add the line `PATH=${PATH}:/c/openshift-project-tools/bin`
1. Restart GIT Bash.  _If you have not done this before, GIT will write out some warnings and create some files for you that fix the issues._

All of the scripts will be avilable on the path and can be run from any directory.  This is imortant as many of the scripts expect to be run from the top level `./openshift` directory you will create in your project.

## Project Structure

To use these scripts your project structure should be organized in one of two ways; split out by component, or simplified.  The one you choose should be based on the complexity of your project and your personal development preferences.

Regardless of which you choose, you will always have a top level `./openshift` directory in your project where you keep you're main project settings (`settings.sh`) file.

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

At a minimun this file should contain definitions for your `PROJECT_NAMESPACE`, `GIT_URI`, and `GIT_REF` all of which should be setup to be overridable.

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
export -a components=(".")

# The builds to be triggered after buildconfigs created (not auto-triggered)
export -a builds=()

# The images to be tagged after build
export -a images=("permitify")

# The routes for the project
export -a routes=("bc-registries" "worksafe-bc")
```

**Full Component Project Structure Example:**
```
export PROJECT_NAMESPACE=${PROJECT_NAMESPACE:-devex-von}
export GIT_URI=${GIT_URI:-"https://github.com/bcgov/TheOrgBook.git"}
export GIT_REF=${GIT_REF:-"master"}

# The templates that should not have their GIT referances(uri and ref) over-ridden
# Templates NOT in this list will have they GIT referances over-ridden
# with the values of GIT_URI and GIT_REF
export -a skip_git_overrides=("schema-spy-build.json" "solr-base-build.json")

# The project components
export -a components=("tob-db" "tob-solr" "tob-api" "tob-web")

# The builds to be triggered after buildconfigs created (not auto-triggered)
export -a builds=("nginx-runtime" "angular-builder")

# The images to be tagged after build
export -a images=("angular-on-nginx" "django" "solr" "schema-spy")

# The routes for the project
export -a routes=("angular-on-nginx" "django" "solr" "schema-spy")
```

## Settings.local.sh

You can also have a `settings.local.sh` file in your top level `./openshift` directory that contains any overrides necessary for deploying your project into a local OpenShift environment.

Typically this will simply contain overrides for the `GIT_URI` and `GIT_REF`, for example:
```
export GIT_URI="https://github.com/WadeBarnes/permitify.git"
export GIT_REF="openshift"
```

These orverrides come into play when you are generating local param files, and deploying into a local OpenShift environment.

## Using the Scripts

When using the scripts run them from the command line in the top level `./openshift` directory of your project.

You will need to install the OC CLI.  Get a recent stable (or the latest) [Openshift Command Line tool](https://github.com/openshift/origin/releases) (oc) and install it by extracting the "oc" executable and placing it somewhere on your path.  You can also install it with several different package managers.

### Starting/Stopping a Local OpenShift Cluster

Use the `oc-cluster-up.sh` script to start a local OpenShift cluster, and `oc-cluster-down.sh` to stop the cluster.

*More documentation to come ...*


# Scripts

*ToDo: Include a short description of all of the scripts ...*


**ToDo: Update the following documentation ...**


## ocFunctions.inc

A set of common functions to include in your scripts.

## createGlusterfsClusterApp.sh

Create/re-create the Gluster file system resources on a project.

## createLocalProject.sh

Creates an project on a local OpenShift cluster.

## deleteLocalProject.sh

Deletes an project from a local OpenShift cluster.

## dropAndRecreateDatabase.sh

A helper script to drop and recreate the application database within a given environment.

Refer to the usage documentation contained in the script for details.  Run the script without parameters to see the documentation.

_This script could be further enhanced to utilize the environment variables within the running pod to determine various database parameters dynamically.  The process will require some fussing around with escaping quotes and such to get things just right._

## getPodByName.sh

A utility script that returns the full name of a running instance of a pod, given the pod's name and optionally the pod index.

Refer to the usage documentation contained in the script for details.  Run the script without parameters to see the documentation.

## grantDeploymentPrivileges.sh

Grants deployment configurations access to the images in the tools project.

## runInContainer.sh

This script is a wrapper around `oc exec` that allows you to run commands inside a pod instance based on it's general name.

Refer to the usage documentation contained in the script for details.  Run the script without parameters to see the documentation.

## scaleDeployment.sh

A helper scrript to scale a deployment to a particular number of pods.

## tagProjectImages.sh

Tags the project's images, as defined in the project's settings.sh file.
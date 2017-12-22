# OpenShift Scripts

A set of scripts to help you configure and maintain your local and production OpenShift projects.

## Environment Setup

1. Clone this repository to your local machine.
1. Update your path to include a reference to the `bin` directory

Using GIT Bash on Windows as an example;
1. Create a `.bashrc` file in your home directory (`C:\Users\<UserName/>`, for ewxample `C:\Users\Wade`).
1. Add the line `PATH=${PATH}:/c/openshift-project-tools/bin`
1. Restart GIT Bash.  _If you have not done this before, GIT will write out some warnings and create some files for you that fix the issues._

All of the scripts will be available on the path and can be run from any directory.  This is important as many of the scripts expect to be run from the top level `./openshift` directory you will create in your project.

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

At a minimum this file should contain definitions for your `PROJECT_NAMESPACE`, `GIT_URI`, and `GIT_REF` all of which should be setup to be overridable.

*When using the Component Project Structure you will also need to override `PROJECT_OS_DIR`.*  Refer to the Full Component Project Structure Example for details.

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
export PROJECT_OS_DIR=${PROJECT_OS_DIR:-../../openshift}

export GIT_URI=${GIT_URI:-"https://github.com/bcgov/TheOrgBook.git"}
export GIT_REF=${GIT_REF:-"master"}

# The templates that should not have their GIT references (uri and ref) over-ridden
# Templates NOT in this list will have they GIT references over-ridden
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

These overrides come into play when you are generating local param files, and deploying into a local OpenShift environment.

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
genParams -l
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

**_Updating the deployment configurations can affect (overwrite) auto-generated secretes such as the database username and password._**

## Fixing routes - for local instances

In the current instance of the deployment, the routes created are explicitly defined for the Pathfinder (BC Gov) instance of OpenShift. Run the script to create the default routes for your local environment:

```
updateRoutes.sh
```

# Scripts

Following is a list of the top level scripts.  There additional lower level scripts that are not listed here since they are wrapped into top level scripts.

Use `-h` to get more detailed usage information on the scripts.

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

This script is a wrapper around `oc exec` that allows you to run commands inside a pod instance based on it's general name.

Refer to the usage documentation contained in the script for details.  Run the script without parameters to see the documentation.

## scaleDeployment.sh

A helper script to scale a deployment to a particular number of pods.

## tagProjectImages.sh

Tags the project's images, as defined in the project's settings.sh file.

## updateRoutes.sh

For use with local instances.  Updates the routes, as defined in the project's settings.sh file.

## exportTemplate.sh

Helper script to export an OpenShift resource as a template.
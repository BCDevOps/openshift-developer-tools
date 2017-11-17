# Example Jenkins file for performing conditional builds

This example is a first pass at eliminating unnecessary builds and deployments within the OpenShift/Jenkins pipeline.

Unfortunately the code contained in a Jenkins file is unable to affect the Pipeline's top level SCM settings to take advantage of the include and exclude filters that would stop the builds from being triggered in the first place.

This example takes steps at the next available level to short-circuit the process, and avoids triggering builds and deployments when there are no changes in the context directory for the pipeline.  A 'build' in the Jenkins sense still gets kicked off, but we avoid re-building and deploying things unnecessarily.

# Examples

For an example of how to use this Jenkins file in context, have a look at [TheOrgBook Solr](https://github.com/bcgov/TheOrgBook/tree/master/tob-solr)

Example of the changes this process makes to an existing pipeline; [Jenkinsfile](https://github.com/WadeBarnes/TheOrgBook/commit/fe580ad430567e87b9d5f2bba1461526108b617b#diff-c425b9c6357af57f2c5f73daa0a9999c)

# Future Enhancements

The current script only looks for changes under a single location.  It would be beneficial for the logic to allow for full include/exclude patterns.

# Credits

Thanks to Angelika Ehlers (agehlers) for diving into the problem and developing the code for the initial `triggerBuild` script.
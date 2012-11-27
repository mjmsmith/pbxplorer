# pbxplorer

 pbxplorer is a set of Ruby classes for parsing, editing, and saving Xcode project (.pbxproj) files.  It can also be used to explore the contents of a project using the interactive Ruby shell.

### Dependencies

pbxplorer has no Ruby dependencies outside of the standard library.  It uses the OS X **plutil** command to parse the project file.

### Overview

An Xcode project (.pbxproj) file is essentially a hash of objects keyed by UUID.  The objects are hashes of properties keyed by name.  The associated values can be strings, arrays, or hashes.

Each object hash contains an "isa" property that identifies its type.  pbxplorer loads a project file hash and replaces each generic object hash with a specific subclass based on its type.

### Class Hierarchy

PBXObject and PBXBuildPhase are abstract superclasses.  All other subclasses of PBXObject correspond to object hashes in the project, based on their "isa" property.

```
PBXObject
    PBXBuildFile
    PBXBuildPhase
        PBXFrameworksBuildPhase
        PBXResourcesBuildPhase
        PBXShellScriptBuildPhase
        PBXSourcesBuildPhase
    PBXFileReference
    PBXGroup
    PBXProject
    PBXNativeTarget
    XCBuildConfiguration
    XCConfigurationList
XCProjectFile
```
  
### Reference Hierarchy

In the project file, objects are referenced from other objects by UUID.  pbxplorer includes convenience methods to return the objects themselves rather than the UUIDs.  Below are the method names and object types returned.

```
PBXProject
    build_configuration_list: XCConfigurationList
    main_group: PBXGroup
    targets: [PBXNativeTarget]
  
XCConfigurationList
    build_configurations: [XCBuildConfiguration]
  
PBXGroup
    children: [PBXGroup|PBXFileReference]
    subgroups: [PBXGroup]
    file_refs: [PBXFileReference]

PBXNativeTarget
    build_configuration_list: XCBuildConfigurationList
    build_phases: [PBXBuildPhase]
    product_file_ref: PBXFileReference

PBXBuildPhase
    build_files: [PBXBuildFile]

PBXBuildFile
    file_ref: PBXFileReference
```

### Interactive Use

To get started:

```ruby
$ irb
>> require 'pbxplorer'
=> true
>> XCProjectFile.help
project_file = XCProjectFile.new '/path/to/project.pbxproj'
=> XCProjectFile
```

The help displays a suggested statement followed by the type of the assigned result.  Enter the statement in the shell, editing as necessary:

```ruby
>> project_file = XCProjectFile.new 'project.pbxproj'
=> {
  rootObject = "4D0B81831657473000DEF560"
  objects = < 63 objects >
}
``` 

This`XCProjectFile`instance contains a reference to the root object (a`PBXProject`instance), and the collection of all objects.

Get help from the **project_file** object:

```ruby
>> project_file.help
project = project_file.project
=> PBXProject
```

Enter the statement:

```ruby
>> project = project_file.project
=> 4D0B81831657473000DEF560 = {
  attributes = {"CLASSPREFIX"=>"Example", "LastUpgradeCheck"=>"0450", "ORGANIZATIONNAME"=>"Example"}
  projectRoot = ""
  hasScannedForEncodings = "0"
  mainGroup = "4D0B81811657473000DEF560"
  buildConfigurationList = "4D0B81861657473000DEF560"
  compatibilityVersion = "Xcode 3.2"
  productRefGroup = "4D0B818D1657473000DEF560"
  projectDirPath = ""
  knownRegions = ["en"]
  targets = ["4D0B818B1657473000DEF560", "4D0B81AC1657473100DEF560"]
  developmentRegion = "English"
  isa = "PBXProject"
}
```

This`PBXProject`instance contains an array of references to targets (`PBXNativeTarget`instances).

Get help from the **project** object:

```ruby
>> project.help
target = project.targets.first
=> PBXNativeTarget
list = project.build_configuration_list
=> XCConfigurationList
group = project.main_group
=> PBXGroup
```

This time the help suggests three objects we can retrieve next; the first`PBXNativeTarget`instance, the sole`XCConfigurationList`instance, and the main`PBXGroup`instance.  

Enter the target statement:

```ruby
>> target = project.targets.first
=> 4D0B818B1657473000DEF560 = {
  productName = "Example"
  productReference = "4D0B818C1657473000DEF560"
  name = "Example"
  dependencies = []
  buildConfigurationList = "4D0B81BF1657473100DEF560"
  productType = "com.apple.product-type.application"
  buildPhases = ["4D0B81881657473000DEF560", "4D0B81891657473000DEF560", "4D0B818A1657473000DEF560"]
  isa = "PBXNativeTarget"
  buildRules = []
}
```

etc

### Example: removing a source file

```ruby
file_ref = project_file.objects_of_class(PBXFileReference, { "path" => "ExampleTests.m" }).first
build_phases = project_file.objects_of_class PBXBuildPhase
build_files = project_file.objects_of_class PBXBuildFile, { "fileRef" => file_ref.uuid }
build_file_uuids = build_files.map { |obj| obj.uuid }
groups = project_file.objects_of_class PBXGroup

build_phases.each { |phase| phase["files"] -= build_file_uuids }
build_files.each { |obj| project_file.remove_object obj }
groups.each { |group| group["children"].delete file_ref }
project_file.remove_object file_ref

project_file.save
```

### Example: adding a source file

```ruby
file_ref = project_file.new_object PBXFileReference, { "path" => "Example.c", "sourceTree" => "<group>",  "lastKnownFileType" => "sourcecode.c.c" }
build_file = project_file.new_object PBXBuildFile, { "fileRef" => file_ref.uuid }

build_phases = project_file.objects_of_class PBXSourcesBuildPhase
build_phases.each { |phase| phase["files"] << build_file.uuid }

project_file.save
```

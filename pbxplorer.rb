require 'json'

class String
  alias to_plist to_json
end

class Array
  def to_plist
    items = self.map { |item| "#{item.to_plist}" }
    "( #{items.join ","} )"
  end
end

class Hash
  def to_plist
    items = self.map { |key, val| "#{key.to_plist} = #{val.to_plist};\n" }
    "{ #{items.join} }"
  end
end

class PBXObject < Hash
  attr_accessor :project_file
  attr_reader :uuid
  
  def self.filter objs, attrs
    objs.select do |obj|
      attrs.select { |key, val| obj[key] == val }.length == attrs.length
    end
  end

  def self.objects_of_class objs, attrs=nil
   objs = objs.select { |obj| obj.class <= self }
   objs = self.filter(objs, attrs) if attrs
   objs
  end
  
  def initialize hash={}, uuid=""
    24.times { uuid += "0123456789ABCDEF"[rand(16),1] } if uuid.empty?
    
    @project = nil
    @uuid = uuid
    
    self.merge! hash
    self["isa"] ||= self.class.to_s
  end

  def inspect
    props = self.map { |key, val| "  #{key} = #{val.inspect}\n" }
    "#{@uuid} = {\n#{props.join}}"
  end

  def help
    puts "(no help available)"
  end
end

class PBXFileReference < PBXObject
end

class PBXBuildFile < PBXObject
  def file_ref
    self.project_file.object_with_uuid self["fileRef"]
  end

  def help
    puts "file_ref = build_file.file_ref"
    PBXFileReference
  end
end

class PBXBuildPhase < PBXObject
  def build_files
    self.project_file.objects_with_uuids self["files"]
  end

  def help
    puts "build_file = build_phase.build_files.first"
    PBXBuildFile
  end
end

class PBXSourcesBuildPhase < PBXBuildPhase
end

class PBXFrameworksBuildPhase < PBXBuildPhase
end

class PBXResourcesBuildPhase < PBXBuildPhase
end

class PBXShellScriptBuildPhase < PBXBuildPhase
end

class PBXGroup < PBXObject
  def children recursive=false
    children = self.project_file.objects_with_uuids self["children"]

    if recursive
      subgroups = PBXGroup.objects_of_class children
      subgroups.each { |subgroup| children << subgroup.children(true) }
    end

    children.flatten
  end
    
  def file_refs recursive=false
    PBXFileReference.objects_of_class self.children(recursive)
  end
  
  def subgroups recursive=false
    PBXGroup.objects_of_class self.children(recursive)
  end

  def help
    puts "file_ref = group.file_refs.first\n=> " + PBXFileReference.to_s
    puts "group = group.subgroups.first"
    PBXGroup
  end
end

class PBXNativeTarget < PBXObject
  def build_phases
    self.project_file.objects_with_uuids self["buildPhases"]
  end

  def build_configuration_list
    self.project_file.object_with_uuid self["buildConfigurationList"]
  end

  def product_file_ref
    self.project_file.object_with_uuid self["productReference"]
  end

  def help
    puts "build_phase = PBXSourcesBuildPhase.objects_of_class(target.build_phases).first"
    PBXSourcesBuildPhase
  end
end

class XCBuildConfiguration < PBXObject
end

class XCConfigurationList < PBXObject
  def build_configurations
    self.project_file.objects_with_uuids self["buildConfigurations"]
  end

  def help
    puts "config = list.build_configurations.first"
    XCBuildConfiguration
  end
end

class PBXProject < PBXObject
  def targets
    self.project_file.objects_with_uuids self["targets"]
  end
  
  def build_configuration_list
    self.project_file.object_with_uuid self["buildConfigurationList"]
  end

  def main_group
    self.project_file.object_with_uuid self["mainGroup"]
  end

  def help
    puts "target = project.targets.first\n=> " + PBXNativeTarget.to_s
    puts "list = project.build_configuration_list\n=> " + XCConfigurationList.to_s
    puts "group = project.main_group"
    PBXGroup
  end
end

class XCProjectFile
  def self.help
    puts "project_file = XCProjectFile.new '/path/to/project.pbxproj'"
    XCProjectFile
  end

  def initialize path
    @path = path
    @path += "/project.pbxproj" if File.directory? @path

    @json = JSON.parse(`plutil -convert json -o - "#{@path}"`)
    
    objs = @json["objects"]
    @json["objects"] = {}

    objs.each do |uuid, hash|
      klass = PBXObject
      begin
        klass = Object.const_get hash["isa"]
      rescue
      end
      
      self.add_object klass.new(hash, uuid)
    end
  end

  def save path=nil
    path ||= @path
    File.open(path, "w") { |f| f.write @json.to_plist }
  end
  
  def project
    self.object_with_uuid @json["rootObject"]
  end

  def uuids
    @json["objects"].keys
  end

  def objects
    @json["objects"].values
  end

  def objects_of_class klass, attrs=nil
   klass.objects_of_class self.objects, attrs
  end

  def objects_with_uuids uuids, attrs=nil
    objs = uuids.map { |uuid| self.object_with_uuid uuid }.reject { |obj| !obj }
    objs = PBXObject.filter(objs, attrs) if attrs
    objs
  end
  
  def object_with_uuid uuid
    @json["objects"][uuid]
  end
  
  def new_object klass, attrs={}
    obj = klass.new attrs
    self.add_object obj
    obj
  end
  
  def add_object obj
    obj.project_file = self
    @json["objects"][obj.uuid] = obj
  end
  
  def remove_object obj
    obj.project_file = nil
    @json["objects"].delete obj.uuid
  end
  
  def remove_file_ref file_ref
    build_files = self.objects_of_class PBXBuildFile, { "fileRef" => file_ref.uuid }
    build_file_uuids = build_files.map { |obj| obj.uuid }
    
    build_files.each { |build_file| self.remove_object build_file }
    self.objects_of_class(PBXBuildPhase).each { |phase| phase["files"] -= build_file_uuids }
    self.objects_of_class(PBXGroup).each { |group| group["children"].delete file_ref }
    self.remove_object file_ref
  end

  def help
    puts "project = project_file.project"
    PBXProject
  end
  
  def inspect
    "{\n  rootObject = #{@json['rootObject'].inspect}\n  objects = < #{@json['objects'].length} objects >\n}"
  end
end

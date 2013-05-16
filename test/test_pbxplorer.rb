require "rubygems"
require "tempfile"
require "test/unit"
require "pbxplorer"

class XCProjectFileTest < Test::Unit::TestCase
  def setup
    @pf = XCProjectFile.new "test"
  end

  def test_read
    assert_not_nil @pf.project
    assert_equal @pf.uuids.length, 63
    assert_equal @pf.objects.length, 63
  end
  
  def test_objects_of_class
    assert_equal @pf.objects_of_class(PBXObject).length, 63
    assert_equal @pf.objects_of_class(PBXBuildPhase).length, 7
    assert_equal @pf.objects_of_class(PBXSourcesBuildPhase).length, 2
    
    assert_equal @pf.objects_of_class(PBXFileReference).length, 19
    objs = @pf.objects_of_class PBXFileReference, {"name" => "Foundation.framework"}
    assert_equal objs.length, 1
    assert_equal @pf.objects_of_class(PBXBuildFile, {"fileRef" => objs.first.uuid}).length, 2
  end
  
  def test_objects_with_uuids
    fr = @pf.objects_of_class(PBXFileReference, {"name" => "Foundation.framework"}).first
    objs = @pf.objects_of_class(PBXBuildFile, {"fileRef" => fr.uuid})
    uuids = objs.map {|obj| obj.uuid}
  
    assert_equal @pf.objects_with_uuids(uuids).length, 2
    uuids << "garbage"
    assert_equal @pf.objects_with_uuids(uuids).length, 2
  end
  
  def test_object_with_uuid
    assert_not_nil @pf.object_with_uuid(@pf.project.uuid)
    assert_nil @pf.object_with_uuid("garbage")
  end
  
  def test_create_remove_object
    obj = @pf.add_object PBXFileReference.new
    assert_equal @pf.objects.length, 64
    assert_not_nil @pf.object_with_uuid(obj.uuid)

    @pf.remove_object obj
    assert_equal @pf.objects.length, 63
    assert_nil @pf.object_with_uuid(obj.uuid)
  end
  
  def test_add_remove_object
    obj = PBXFileReference.new
    @pf.add_object obj
    assert_equal @pf.objects.length, 64
    assert_not_nil @pf.object_with_uuid(obj.uuid)
    
    @pf.remove_object obj
    assert_equal @pf.objects.length, 63
    assert_nil @pf.object_with_uuid(obj.uuid)
  end
  
  def test_save
      path = nil
      Tempfile.open("test_save_") { |f| path = f.path }
      @pf.save path
      new_pf = XCProjectFile.new path

      assert_not_nil new_pf
      assert_equal @pf.objects.length, new_pf.objects.length
  end
  
  def test_edit_save
      path = nil
      Tempfile.open("test_save_") { |f| path = f.path }

      obj = @pf.add_object PBXFileReference.new
      @pf.save path

      old_pf = XCProjectFile.new "test"
      new_pf = XCProjectFile.new path
      
      assert_not_nil new_pf
      assert_equal (old_pf.objects.length + 1), new_pf.objects.length
      assert_nil old_pf.object_with_uuid obj.uuid
      assert_not_nil new_pf.object_with_uuid obj.uuid
  end
  
  def test_remove_file_ref
      path = nil
      Tempfile.open("test_save_") { |f| path = f.path }

      fr = @pf.objects_of_class(PBXFileReference, {"name" => "Foundation.framework"}).first
      bfs = @pf.objects_of_class(PBXBuildFile, {"fileRef" => fr.uuid})
      @pf.remove_file_ref fr
      @pf.save path
      
      old_pf = XCProjectFile.new "test"
      new_pf = XCProjectFile.new path
      
      assert_not_nil new_pf
      assert_equal (old_pf.objects.length - 3), new_pf.objects.length
      (bfs + [fr]).each do |obj|
        assert_not_nil old_pf.object_with_uuid obj.uuid
        assert_nil new_pf.object_with_uuid obj.uuid
      end
  end
end

class PBXProjectTest < Test::Unit::TestCase
  def setup
    @project = XCProjectFile.new("test").project
  end

  def test_properties
    assert_equal @project.targets.length, 2
    assert_equal @project.build_configuration_list.uuid, "4D0B81861657473000DEF560"
    assert_equal @project.main_group.uuid, "4D0B81811657473000DEF560"
  end
end

class XCConfigurationListTest < Test::Unit::TestCase
  def setup
    @list = XCProjectFile.new("test").project.build_configuration_list
  end
  
  def test_properties
    assert_equal @list.build_configurations.length, 2
  end
end


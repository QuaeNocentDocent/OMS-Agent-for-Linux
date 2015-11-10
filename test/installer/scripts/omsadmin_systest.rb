require 'digest'

class OmsadminTest < Test::Unit::TestCase
  
  TEST_WORKSPACE_ID=ENV['TEST_WORKSPACE_ID']
  TEST_SHARED_KEY=ENV['TEST_SHARED_KEY']
  TEST_WORKSPACE_ID_2=ENV['TEST_WORKSPACE_ID_2']
  TEST_SHARED_KEY_2=ENV['TEST_SHARED_KEY_2']

  def setup
    @base_dir = ENV['BASE_DIR']
    @ruby_test_dir = ENV['RUBY_TESTING_DIR']
    @omsadmin_test_dir = nil
    @omsadmin_script = nil
    prep_omsadmin
  end

  def teardown
    if @omsadmin_test_dir
      assert_equal(true, File.directory?(@omsadmin_test_dir))
      FileUtils.rm_r @omsadmin_test_dir
      assert_equal(false, File.directory?(@omsadmin_test_dir))
    end
  end

  def check_test_keys
    keys = [TEST_WORKSPACE_ID, TEST_SHARED_KEY, TEST_WORKSPACE_ID_2, TEST_SHARED_KEY_2]
    keys.each_with_index {|key, index| 
      assert(key != nil, "Keys[#{index}] should be set by the environment for this test to run.") 
      assert(key.empty? == false, "Keys[#{index}] should not be empty.")
    }
  end

  def prep_omsadmin
    # Setup test onboarding script and folder
    prep_omsadmin_script = "#{ENV['BASE_DIR']}/test/installer/scripts/prep_omsadmin.sh"
    @omsadmin_test_dir = `#{prep_omsadmin_script} #{@base_dir} #{@ruby_test_dir}`.strip()
    result = $?
    assert_equal(0, result.to_i, "Unexpected failure setting up the test")
    assert_equal(true, File.directory?(@omsadmin_test_dir), "'#{@omsadmin_test_dir}' does not exist!")

    @omsadmin_script = "#{@omsadmin_test_dir}/omsadmin.sh"
    assert_equal(true, File.file?(@omsadmin_script), "'#{@omsadmin_script}' does not exist!")
    assert_equal(true, File.executable?(@omsadmin_script), "'#{@omsadmin_script}' is not executable.")
  end

  def check_cert_perms(path)
    stat = File.stat(path)
    assert_equal(nil, stat.world_readable?, "'#{path}' should not be world readable")
    assert_equal(nil, stat.world_writable?, "'#{path}' should not be world writable")
    assert_equal(true, stat.writable?, "'#{path}' should be writable")
    assert_equal(true, stat.readable?, "'#{path}' should be readable")
  end
  
  def do_onboard(workspace_id, shared_key, should_succeed = true)
    onboard_out = `#{@omsadmin_script} -w #{workspace_id} -s #{shared_key}`
    result = $?
    if should_succeed
      assert_equal(0, result.to_i, "Unexpected failure onboarding : '#{onboard_out}'")
      assert_match(/Onboarding success/, onboard_out, "Did not find onboarding success message")
    else
      assert_not_equal(0, result.to_i, "Onboarding was expected to fail but exited with a return code of 0")
      assert_match(/Error/, onboard_out, "Did not find onboarding error message")
    end
    return onboard_out
  end
  
  def post_onboard_validation
    crt_path = "#{@omsadmin_test_dir}/oms.crt"
    key_path = "#{@omsadmin_test_dir}/oms.key"

    # Make sure certs and config was generated
    assert(File.file?(crt_path), "'#{crt_path}' does not exist!")
    assert(File.file?(key_path), "'#{key_path}' does not exist!")
    assert(File.file?("#{@omsadmin_test_dir}/omsadmin.conf"), "omsadmin.conf does not exist!")

    # Check permissions
    crt_uid = File.stat(crt_path).uid
    key_uid = File.stat(key_path).uid
    assert(crt_uid == key_uid, "Key and cert should have the same uid")    
    check_cert_perms(crt_path)
    check_cert_perms(key_path)
  end

  def test_onboard_success
    check_test_keys()
    output = do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)
    assert_match(/Generating certificate/, output, "Did not find cert generation message")
    post_onboard_validation
  end

  def test_onboard_fail
    require 'securerandom'
    check_test_keys()
    output = do_onboard(SecureRandom.uuid, TEST_SHARED_KEY, false)
    assert_no_match(/HTTP|code/, output)
    assert_match(/Error during the onboarding request/, output)
  end

  def get_GUID
    conf = File.read("#{@omsadmin_test_dir}/omsadmin.conf")
    guid = conf[/AGENT_GUID=(.*)/, 1]
    return guid
  end

  def test_reonboard
    check_test_keys()
    do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)

    crt_path = "#{@omsadmin_test_dir}/oms.crt"
    key_path = "#{@omsadmin_test_dir}/oms.key"

    # Save state
    crt_hash = Digest::SHA256.file(crt_path)
    key_hash = Digest::SHA256.file(key_path)
    old_guid = get_GUID()
    
    # Reonboarding should not modify the agent GUID or the certs 
    output = do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)
    assert_match(/Reusing previous agent GUID/, output, "Did not find GUID reuse message")
    assert_equal(old_guid, get_GUID(), "Agent GUID should not change on reonboarding")
    assert(crt_hash == Digest::SHA256.file(crt_path), "The cert should not change on reonboarding")
    assert(key_hash == Digest::SHA256.file(key_path), "The key should not change on reonboarding")
  end

  def test_reonboard_different_workspace_id
    check_test_keys()
    do_onboard(TEST_WORKSPACE_ID, TEST_SHARED_KEY)
    old_guid = get_GUID()

    output = do_onboard(TEST_WORKSPACE_ID_2, TEST_SHARED_KEY_2)
    new_guid = get_GUID()

    assert_not_equal(old_guid, new_guid, "The GUID should change when reonboarding with a different workspace ID")
    assert_no_match(/Reusing/, output, "Should not be reusing GUID")
  end

end

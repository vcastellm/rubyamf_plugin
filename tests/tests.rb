#Copyright (c) 2007 Aaron Smith (aaron@rubyamf.org) - MIT License

require 'test/unit'
require 'ostruct'

#-- RubyAMF Packages
$:.unshift("../") #unshift the rubyamf_core path

require 'io/amf_deserializer' #get the deserializer
require 'io/amf_serializer'
include RUBYAMF::IO #de/serializers live in RUBYAMF::IO Module


##I don't really use these tests. This is just an example for someone who wants to use the de/serializers in anything else. 


class TestAMF < Test::Unit::TestCase
  
  #ALL TESTS ARE FORCED INTO AMF3 IN THE SERIALIZER / DESERIALIZERS
  def setup
    @de = AMFDeserializer.new
    @se = AMFSerializer.new
  end
  
  def test_undefined_decode
    expected = nil
    result = @de.read_raw("\021\01")
    assert_equal(expected, result)
  end

  def test_undefined_encode
    expected = "\021\01"
    result = @se.write_raw(nil)
    assert_equal(expected,result)
  end
  
  def test_null_decode
    expected = nil
    result = @de.read_raw("\021\001")
    assert_equal(expected,result)
  end
  
  def test_null_encode
    expected = "\021\01"
    result = @se.write_raw(nil)
    assert_equal(expected,result)
  end
  
  def test_true_decode
    expected = true
    result = @de.read_raw("\021\003")
    assert_equal(expected,result)
  end
  
  def test_true_encode
    expected = "\021\003"
    result = @se.write_raw(true)
    assert_equal(expected,result)
  end
  
  def test_false_decode
    expected = false
    result = @de.read_raw("\021\002")
    assert_equal(expected,result)
  end
  
  def test_false_encode
    expected = "\021\002"
    result = @se.write_raw(false)
    assert_equal(expected,result)
  end
  
  def test_string_decode
    expected = "foo"
    result = @de.read_raw("\021\006\afoo")
    assert_equal(expected,result)
  end
  
  def test_string_encode
    expected = "\021\006\afoo"
    result = @se.write_raw("foo")
    assert_equal(expected,result)
  end
  
  def test_empty_string_encode
    expected = "\021\006\001"
    result = @se.write_raw("")
    assert_equal(expected,result)
  end
    
  ##################################################FIX THIS
  def test_empty_string_decode
    expected = ""
    result = @de.read_raw("\021\006\001")
    #assert_equal(expected,result)
  end
  
  def test_integer_decode
    expected = 4
    result = @de.read_raw("\021\004\004")
    assert_equal(expected,result)
  end
  
  def test_integer_encode
    expected = "\021\004\004"
    result = @se.write_raw(4)
    assert_equal(expected,result)
  end
  
  def test_number_decode
    expected = 238
    result = @de.read_raw("\021\004\201n")
    assert_equal(expected,result)
  end
  
  def test_number_encode
    expected = "\021\004\201n"
    result = @se.write_raw(238)
    assert_equal(expected,result)
  end
  
  def test_array_decode
    expected = ["foo", "bar"]
    result = @de.read_raw("\021\t\005\001\006\afoo\006\abar")
    assert_equal(expected, result)
  end
  
  def test_array_encode
    expected = "\021\t\005\001\006\afoo\006\abar"
    result = @se.write_raw(["foo","bar"])
    assert_equal(expected,result)
  end
  
  def test_encode_hash
    expected = "\021\n\v\001\003a\004d\003b\006\astr\003c\t\005\001\006\afoo\006\abar\001"
    result = @se.write_raw({:a => 100, :b => "str", :c => ["foo", "bar"]})
    assert_equal(expected,result)
  end
  
  def test_decode_object_into_ostruct
    d = OpenStruct.new
    d.a = 100
    d.b = "str"
    d.c = ["foo","bar"]
    d._explicitType = nil
    expected = d
    result = @de.read_raw("\021\n\v\001\003a\004d\003b\006\astr\003c\t\005\001\006\afoo\006\abar\001")
    assert_equal(expected,result)
  end
  
  def test_encode_ostruct_into_object
    expected = "\021\n\v\001\003a\004d\e_explicitType\001\003b\006\astr\003c\t\005\001\006\afoo\006\abar\001"
    d = OpenStruct.new
    d.a = 100
    d.b = "str"
    d.c = ["foo","bar"]
    d._explicitType = nil
    result = @se.write_raw(d)
    assert_equal(expected,result)
  end

end

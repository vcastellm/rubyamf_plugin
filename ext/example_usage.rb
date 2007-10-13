require 'amf/amf_deserializer'
require 'amf/amf_serializer'

#AMFRequest is used for a complete RubyAMF HTTP POST/GET request
a = AMFRequest.new(raw)
rubydata = a.deserialize()
bodies = a.bodies
bodies[0].someBodyMethodOrProperty
headers = a.headers
headers[0].someHeaderMethodOrProperty
a.bodies.length
a.headers.length
a.outheaders.length
version = a.version
a.add_header(someAMFHeader)
a.get_header_at(index)
a.add_header_at(index,body)
a.get_header_by_key(key)
a.get_outheader_at(index)
a.add_outheader(index)
a.get_outheader_at(inded)
a.get_outheaders
a.get_body_at(index)
a.add_body_at(index,body)
a.add_body(someAMFBody)
a.add_body_top(body)
amfdata = a.serialize()
#more methods from AMFObject

#AMFSerializer is used to serialize ruby objects
#this doesn't give you a full AMF response with headers / bodies though.
#Just the raw AMF stream data for the Ruby object passed)
s = AMFSerializer.new
output = s.write_raw(rubv_data)
output = s.write_raw(more_ruby_data)
s.output_stream

#AMFDeserializer is used to deserialize some raw AMF data
#returns a complete ruby data structure for you
d = AMFDeserializer.new
rbdata = d.read_raw(raw)
rbdata2 = d.read_raw(moreraw)
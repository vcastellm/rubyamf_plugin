// amf_body.c - A generic AMFBody object
// Copyright (c) 2007 rubyamf.org (aaron@rubyamf.org)
// License - http://www.gnu.org/copyleft/gpl.html

//A LOT OF THIS STUFF IS STUB CODE FOR NOW.
#include "ruby.h"

//AMF3 codes
#define AMF3_TYPE 0x11
#define AMF3_UNDEFINED 0x00
#define AMF3_NULL 0x01
#define AMF3_FALSE 0x02
#define AMF3_TRUE 0x03
#define AMF3_INTEGER 0x04
#define AMF3_NUMBER 0x05
#define AMF3_STRING 0x06
#define AMF3_XML 0x07
#define AMF3_DATE 0x08
#define AMF3_ARRAY 0x09
#define AMF3_OBJECT 0x0A
#define AMF3_XML_STRING 0x0B
#define AMF3_BYTE_ARRAY 0x0C
#define AMF3_INTEGER_MAX 268435455
#define AMF3_INTEGER_MIN -268435456

//holds an amf "chunk", every method that writes amf creates amf_chunks.
//this is for performance so i'm not passing around huge strings.
struct amf_chunk
{
	char[] data;
}

//AMF_output chunks, an array of amf_chunk
struct amf_output_chunks
{
	amf_chunk*[] pieces;
}amf_output_chunks[];

*[20] amf_stored_strings;
*[20] amf_stored_objects;
*[20] amf_stored_defs;

//reset referencable variables
void resetReferencables()
{
	amf_stored_strings = [20];
	amf_stored_objects = [20];
	amf_stored_defs = [20];
}

//for RubyAMF write process
static VALUE amf_serializer_rubyamf_write(VALUE self, VALUE bs, VALUE obj, int encoding){}

//for Generic AMF writing
static VALUE amf_serializer_write_raw(VALUE self,VALUE bs, VALUE obj, int encoding)
{
	if(encoding == NULL)	encoding = 3;
	resetReferencables();
	binaryString = bs;
	amf_output_stream = get_new_output_stream(); //##TODO
	amf_write(obj);
	return binaryString;
}

//write some amf
void amf_write(VALUE obj)
{
	if(encoding == 3)
	{
		write_byte(AMF3_TYPE)
		write_amf3(obj);
	}
}

//write some AMF3 to the output_stream
void write_amf3(obj)
{
	if(obj == Qtrue)
		write_amf3_true
	else if(obj == Qfalse)
		write_amf3_false
	else if(obj == Qnil)
		write_amf3_null
	else if(rb_is_kind_of(obj, "Float"))
		amf_write_number(obj); 
	else if(rb_is_kind_of(obj, "Integer"))
		amf_write_number(obj);
	else if(rb_is_kind_of(obj, "Bignum"))
		amf_write_number(obj);
	else if(rb_is_kind_of(obj, "Fixnum"))
		amf_write_number(obj);
	else if(rb_is_kind_of(obj, "Numeric"))
		amf_write_number(obj);
	else if(rb_is_kind_of(obj, "String"))
		amf3_write_string(obj);
	else if(rb_is_kind_of(obj, "Array"))
		amf3_write_array(obj)
	else if(rb_is_kind_of(obj, "Hash"))
		amf3_write_hash(obj);
	else if(rb_is_kind_of(obj, "Date"))
		amf3_write_date(obj);	
	else if(rb_is_kind_of(obj, "Time"))
		amf3_write_date(obj);
	else if(rb_is_kind_of(obj, "REXML::Document"))
		amf3_write_xml(obj);
	else if(rb_respond_to(obj, ":to_xml"))
		amf3_write_xml(obj);
	else 
		write_object(obj);
}

static void write_byte(* buf, int value)
{
	buf->appendByte(value);  //##TODO
}

static void write_double(* buf, double value)
{
	buf->appendDouble(value);  //##TODO
}

static void write_amf3_false()
{
	buf->appendFalse();
}

static void amf3_write_null()
{
	buf->appendNull();
}

static void write_amf3_true()
{
	buf->appendTrue();
}

/************************AMF3 */
/**  writes an integer in AMF3 format as a variable bytes */
static void amf3_write_integer(* buf, amf_serialize_output buf, int value  AMFTSRMLS_DC)
{
	value &= 0x1fffffff;
	if(value < 0x80)
	{
		amf_write_byte(amf_output_buf,value);
	}
	else if(value < 0x4000)
	{
		amf_write_byte(amf_output_buf,value >> 7 & 0x7f | 0x80);
		amf_write_byte(amf_output_buf,value & 0x7f);
	}
	else if(value < 0x200000)
	{
		amf_write_byte(amf_output_buf,value >> 14 & 0x7f | 0x80);
		amf_write_byte(amf_output_buf,value >> 7 & 0x7f | 0x80);
		amf_write_byte(amf_output_buf,value & 0x7f);
	} 
	else
	{
		char tmp[4] = { value >> 22 & 0x7f | 0x80, value >> 15 & 0x7f | 0x80, value >> 8 & 0x7f | 0x80, value & 0xff };
		amf_write_string(amf_output_buf, tmp);
	}
}

static inline void amf_write_number(* buf, double val)
{
	buf->appendByte(0);  //##TODO
	buf->appendDouble(val); //##TODO
}

static inline void amf3_write_string(* val) //##TODO
{  
  if(val == "")
  {
		write_byte(0x01)
	} 
  else
	{
		if(stored_strings[i] != NULL)
		{
			i = stored_strings[i]
      reference = i << 1
      write_amf3_integer(reference)
		}
    else
		{
      stored_strings << value
      reference = value->length
      reference = reference << 1
      reference = reference | 1
      write_amf3_integer(reference)
      output_stream.write(value)
		}
	}
}

static void amf3_write_object(VALUE obj)
{
	//###TODO
	if(stored_objects[obj] != NULL)
	{
		i = stored_objects[value]
		reference = i << 1
		write_amf3_integer(reference)
	}
	else
	{
		if(rb_is_kind_of(obj, "OpenStruct"))
      members = value.marshal_dump.keys.map{|k| k.to_s} #returns an array of all the keys in the OpenStruct  //##TODO
		
		//#Type this as a dynamic object  ##TODO
		write_byte(buf, 0x0B)
		
		if(rb_iv_get(obj, "@_explicitType") != NULL)
		  classname = rb_iv_get(obj, "@_explicitType") //TODO handle class mappings here
		else
		  classname = ""
		
   	stored_objects << value #add object here for circular references //##TODO
 		
		write_amf3_string(buf, classname)
    
		//##### TODO re-write this loop
		members.each_with_index do |v,i|
      val = eval("value.#{v}")
      write_amf3_string(v)
      if(val == nil)
        @output_stream.write_byte(AMF3_NULL)
      else
        write_amf3(val)
    end
		
		write_amf3_string(output_stream_buf, "")
	}
}

static void amf3_write_array(VALUE obj)
{
	if(!rb_is_kind_of(obj, "Array"))
		rb_raise("Error writing array as AMF3, something other than an array was passed to amf3_write_array");
}

//Ruby Extension Initialization Code
VALUE cAMFSerializer;
void Init_Amf(VALUE self)
{
	cAMFSerializer = rb_define_class("AMFSerializer",rb_cObject);
	rb_define_method(cAMFSerializer, "initialize", amf_serializer_initialize, 0);
	rb_define_method(cAMFSerializer, "write_raw", amf_serializer_write_raw, 1);
	rb_define_method(cAMFSerializer, "rubyamf_write", amf_serializer_rubyamf_write, 1);
}
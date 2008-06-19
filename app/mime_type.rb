# Adding amf to the list of mime type formats that are not checked for forgery protection
# at the time of writing (rails 2.1) the other types were [:text, :json, :csv, :xml, :rss, :atom, :yaml]
Mime::Type.unverifiable_types << :amf if defined? Mime::Type.unverifiable_types
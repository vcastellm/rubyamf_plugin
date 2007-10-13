class String
  #"FooBar".snake_case #=> "foo_bar"
  def snake_case
    gsub(/\B[A-Z]/, '_\&').downcase
  end
  
  def camlize(type)
    words = split("_").map!{ |x| x.capitalize }
    if type == :lower
      words[0] = words[0].downcase
    end
    humps = words.join("")
    return humps
  end
  
end
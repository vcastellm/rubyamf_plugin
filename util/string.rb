class String

  def to_snake! # no one should change these unless they can benchmark and prove their way is faster. =)
    @cached_snake_strings ||= {}
    @cached_snake_strings[self] ||= (
      while x = index(/([a-z\d])([A-Z\d])/) # unfortunately have to use regex for this one
        y=x+1
        self[x..y] = self[x..x]+"_"+self[y..y].downcase
      end
      self
    )
  end
  
  # Aryk: This might be a better way of writing it. I made a lightweight version to use in my modifications. Feel free to adapt this to the rest.
  def to_camel! # no one should change these unless they can benchmark and prove their way is faster. =)
    @cached_camel_strings ||= {}
    @cached_camel_strings[self] ||= (
      # new_string = self.dup # need to do this since sometimes the string is frozen
      while x = index("_")
        y=x+1
        self[x..y] = self[y..y].capitalize # in my tests, it was faster than upcase
      end
      self
    )
  end
  
  def to_title
   title = self.dup
   title[0..0] = title[0..0].upcase
   title
  end
  
end
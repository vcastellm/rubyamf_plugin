#initialize big decimal types
require 'bigdecimal'
NaN = BigDecimal.new("NaN")
Infinity = BigDecimal.new('Infinity')
NInfinity = BigDecimal.new('-Infinity')

#TOP LEVEL Support methods
def isNaN(val)
  if val.class.to_s == 'BigDecimal'
    return val.nan?
  end
  false
end

def isFinite(num)
  c = num.class.to_s
  if c == 'BigDecimal'
    if num.finite?
      return true
    elsif num.inifinite?
      return false
    elsif num.nan?
      return false
    end
  end
  if c != 'Numeric' && c != 'Bignum' && c != 'Fixnum' && c != 'Float' && c != 'Integer' && c != 'Fixnum'
    false
  end
  true
end

alias :isFinite? :isFinite
alias :isNaN? :isNaN
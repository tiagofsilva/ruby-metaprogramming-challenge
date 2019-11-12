    module A; def b; end; class << self; include A; end; end
    10.times{ A.b }

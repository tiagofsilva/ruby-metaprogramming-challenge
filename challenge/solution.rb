class_method_tuple = ENV['COUNT_CALLS_TO']
matches = class_method_tuple.match(/(\w.*)(\.|\#)(.+)/)
class_name, method_type, method_name = matches[1..3]
is_singleton = method_type == '.'
count = 0

def class_name_for(receiver)
  (receiver.is_a?(Class) || receiver.is_a?(Module)) ? receiver.name : receiver.class.name
end

def singleton_method?(klass, method_name)
  klass.singleton_methods(false).include?(method_name.to_sym)
end

def class_or_module?(unit)
  unit.is_a?(Module) || unit.is_a?(Class)
end

define_method :alias_and_override_method do |klass, mname|
  owner_class = is_singleton ? klass.singleton_class : klass
  owner_class.class_eval do
    if !instance_methods(false).include?(:"old_#{mname}") && method_defined?(mname)
      alias_method "old_#{mname}", mname
      define_count_method(mname)
    end
  end
end

define_method :define_count_method do |mname|
  define_method mname do |*args, &block|
    count = count.succ
    send("old_#{mname}", *args, &block)
  end
end

begin
  klass = Object.const_get(class_name, true)
  alias_and_override_method(klass, method_name)
rescue NameError
  adder = lambda do |method|
    if method.to_s == method_name && self.name == class_name
      alias_and_override_method(self, method_name)
    end
  end

  includer = lambda do |receiver|
    receiver_class = class_or_module?(receiver) ? receiver : receiver.class
    if receiver_class.name == class_name
      alias_and_override_method(receiver_class, method_name)
    end
  end

  inheriter = lambda do |receiver|
    if receiver.name == class_name
      alias_and_override_method(receiver.superclass, method_name)
    end
  end

  Module.send(:define_method, :method_added, adder)
  Module.send(:define_method, :singleton_method_added, adder)
  Module.send(:define_method, :included, includer)
  Module.send(:define_method, :extended, includer)
  Class.send(:define_method, :inherited, inheriter)
end

at_exit do
  puts "#{class_method_tuple} was called #{count} times"
end

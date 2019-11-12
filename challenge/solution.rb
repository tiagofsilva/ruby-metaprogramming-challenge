class_method_tuple = ENV['COUNT_CALLS_TO']
matches = class_method_tuple.match(/(\w.*)(\.|\#)(.+)/)
class_name, method_type, method_name = matches[1..3]
is_singleton = method_type == '.'
stop_recursion = false
count = 0

define_method :alias_and_override_method do |klass, mname|
  if is_singleton
    klass.singleton_class.class_eval do
      alias_method "old_#{mname}", mname
      define_count_method(mname)
    end
  else
    klass.class_eval do
      if !self.instance_methods(false).include?("old_#{mname}")
        alias_method "old_#{mname}", mname
        define_count_method(mname)
      end
    end
  end
end

define_method :define_count_method do |method_name|
  define_method method_name do |*args, &block|
    count = count.succ
    send("old_#{method_name}", *args, &block)
  end
end

def class_name_for(receiver)
  receiver.is_a?(Class) ? receiver.name : receiver.class.name
end

begin
  klass = Object.const_get(class_name, true)
  alias_and_override_method(klass, method_name)
rescue NameError
  adder = lambda do |method|
    if method.to_s == method_name && self.name == class_name && !stop_recursion
      stop_recursion = true
      alias_and_override_method(self, method_name)
    end
  end

  includer = lambda do |receiver|
    puts '>>>> includer'
    if class_name_for(receiver) == class_name && !stop_recursion
      stop_recursion = true
      alias_and_override_method(receiver, method_name)
    end
  end

  inheriter = lambda do |receiver|
    puts '>>>> inheriter'
    if receiver.name == class_name && receiver.superclass.instance_methods.include?(method_name.to_sym)
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

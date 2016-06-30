module CephRuby
  # Representation of a File extended Attribute
  class Xattr
    attr_accessor :name, :pool, :object_name

    def initialize(rados_object, name)
      raise Errno::ENOENT, 'RadosObject is nil' unless rados_object.exists?
      raise SystemCallError.new(
        'xattr name cannot be nil',
        Errno::ENOENT::Errno
      ) if name.nil?
      self.object_name = rados_object.name
      self.pool = rados_object.pool
      self.name = name
      yield(self) if block_given?
    end

    def value(size = 4096)
      read size
    end

    def value=(value)
      write value
    end

    def destroy
      log('destroy')
      CephRuby.rados_call("destruction of xattr '#{name}'") do
        Lib::Rados.rados_rmxattr(pool.handle,
                                 object_name,
                                 name)
      end
    end

    def to_s
      read
    end

    def log(message)
      CephRuby.log('rados obj xattr '\
                   "#{object_name}/#{name} #{message}")
    end

    private

    def read(size)
      log("read #{size}b")
      data_p = FFI::MemoryPointer.new(:char, size)
      r = CephRuby.rados_call("xattr read '#{name}'") do
        Lib::Rados.rados_getxattr(pool.handle,
                                  object_name,
                                  name, data_p, size)
      end
      data_p.get_bytes(0, r)
    end

    def write(data)
      size = data.bytesize
      log("write size #{size}")
      CephRuby.rados_call("xattr write '#{name}'") do
        Lib::Rados.rados_setxattr(pool.handle,
                                  object_name,
                                  name, data, size)
      end
    end
  end
end

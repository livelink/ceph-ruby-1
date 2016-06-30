module CephRuby
  # An Object in Ceph
  class RadosObject
    attr_accessor :pool, :name

    def initialize(pool, name)
      self.pool = pool
      self.name = name
      yield(self) if block_given?
    end

    def exists?
      log('exists?')
      !stat.nil?
    rescue SystemCallError => e
      return false if e.errno == Errno::ENOENT::Errno
      raise e
    end

    def overwrite(data)
      size = data.bytesize
      log("overwrite size #{size}")
      CephRuby.rados_call("overwrite of #{size} bytes to '#{name}' failed") do
        Lib::Rados.rados_write_full(pool.handle, name, data, size)
      end
    end

    def write(offset, data)
      size = data.bytesize
      log("write offset #{offset}, size #{size}")
      CephRuby.rados_call("cannot write #{size}B to '#{name}'") do
        Lib::Rados.rados_write(pool.handle, name, data, size, offset)
      end
    end

    def append(data)
      size = data.bytesize
      log("append #{size}B")
      CephRuby.rados_call("appending #{size} bytes to '#{name}' failed") do
        Lib::Rados.rados_append(pool.handle, name, data, size)
      end
    end

    alias exist? exists?

    def read(offset, size)
      log("read offset #{offset}, size #{size}")
      data_p = FFI::MemoryPointer.new(:char, size)
      r = CephRuby.rados_call("read #{size}B from '#{name}' failed") do
        Lib::Rados.rados_read(pool.handle, name, data_p, size, offset)
      end
      data_p.get_bytes(0, r)
    end

    def read_full
      log('read_full')
      read 0, size
    end

    def destroy
      log('destroy')
      CephRuby.rados_call("destruction of '#{name}' failed") do
        Lib::Rados.rados_remove(pool.handle, name)
      end
    end

    def resize(size)
      log("resize size #{size}")
      CephRuby.rados_call("resize of '#{name}' to #{size} failed") do
        Lib::Rados.rados_trunc(pool.handle, name, size)
      end
    end

    def stat
      log('stat')

      RadosObject::Stat.new(self).to_h
      # size_p = FFI::MemoryPointer.new(:uint64)
      # mtime_p = FFI::MemoryPointer.new(:uint64)
      # CephRuby.rados_call("stat of '#{name}' failed") do
      #   Lib::Rados.rados_stat(pool.handle, name, size_p, mtime_p)
      # end
      # RadosObject.stat_hash(size_p, mtime_p)
    end

    class Stat
      attr_accessor :pool, :rados_object

      def initialize(rados_object)
        self.rados_object = rados_object
        self.pool = rados_object.pool
      end

      def stats
        CepRuby.rados_call("stat of '#{rados_object.name}' failed") do
          Lib::Rados.rados_stat(pool.handle, rados_object.name, size_p, mtime_p)
        end
      end

      def size_p
        @size_p ||= FFI::MemoryPointer.new(:uint64)
      end

      def mtime_p
        @mtime_p ||= FFI::MemoryPointer.new(:uint64)
      end

      def to_h
        {
           size: size_p.get_uint64(0),
           mtime: Time.at(mtime_p.get_uint64(0))
        }
      end
    end

    class << self
      def stat_hash(size_p, mtime_p)
        {
          size: size_p.get_uint64(0),
          mtime: Time.at(mtime_p.get_uint64(0))
        }
      end
    end

    def size
      stat[:size]
    end

    def mtime
      stat[:mtime]
    end

    def xattr(name = nil)
      Xattr.new(self, name)
    end

    def xattr_enumerator
      ::CephRuby::XattrEnumerator.new(self)
    end

    def <=>(other)
      pool_check = pool <=> other.pool
      return pool_check unless pool_check == 0
      other.name <=> name
    end

    def eql?(other)
      return false unless other.class == self.class
      self == other
    end

    # helper methods below

    def log(message)
      CephRuby.log("rados object #{pool.name}/#{name} #{message}")
    end
  end
end

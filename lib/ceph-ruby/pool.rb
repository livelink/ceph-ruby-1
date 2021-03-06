module CephRuby
  # Represents a Ceph pool
  # = usage
  # pool = cluster.pool('name')
  class Pool
    extend CephRuby::PoolHelper
    include CephRuby::PoolHelper
    include ::Comparable
    attr_accessor :cluster_handle, :name, :handle

    def initialize(cluster, name)
      self.cluster_handle = cluster.handle
      self.name = name
      begin
        yield(self)
      ensure
        close
      end if block_given?
    end

    def exists?
      log('exists?')
      CephRuby.rados_call("lookup of '#{name}'") do
        Lib::Rados.rados_pool_lookup(cluster_handle, name)
      end
      true
    rescue Errno::ENOENT
      false
    end

    alias exist? exists?

    def id
      ensure_open
      Lib::Rados.rados_ioctx_get_id(handle)
    end

    def auid=(dst_auid)
      log("auid=#{dst_auid}")
      ensure_open
      CephRuby.rados_call("set of auid for #{name}") do
        Lib::Rados.rados_ioctx_pool_set_auid(handle, dst_auid)
      end
    end

    def auid
      log('auid')
      ensure_open
      auid_p = FFI::MemoryPointer.new(:uint64)
      CephRuby.rados_call("get auid for #{name}") do
        Lib::Rados.rados_ioctx_pool_get_auid(handle, auid_p)
      end
      auid_p.get_uint64(0)
    end

    def open
      return if open?
      log('open')
      handle_p = FFI::MemoryPointer.new(:pointer)
      CephRuby.rados_call("creation of io context '#{name}'") do
        Lib::Rados.rados_ioctx_create(cluster_handle, name, handle_p)
      end
      self.handle = handle_p.get_pointer(0)
    end

    def close
      return unless open?
      log('close')
      Lib::Rados.rados_ioctx_destroy(handle)
      self.handle = nil
    end

    def rados_object(name, &block)
      ensure_open
      RadosObject.new(self, name, &block)
    end

    def rados_object_enumerator(&block)
      ensure_open
      RadosObjectEnumerator.new(self, &block)
    end

    def rados_block_device(name, &block)
      ensure_open
      RadosBlockDevice.new(self, name, &block)
    end

    def create(auid: nil, rule_id: nil)
      log("create auid: #{auid}, rule: #{rule_id}")
      rule_id ||= 0
      return create_with_all(auid, rule_id) if auid
      create_with_rule(rule_id)
      close
    end

    def destroy
      CephRuby.rados_call('delete pool') do
        Lib::Rados.rados_pool_delete(cluster_handle, name)
      end
    end

    def stat
      log('stat')
      stat_s = Lib::Rados::PoolStatStruct.new
      ensure_open
      CephRuby.rados_call('stat') do
        Lib::Rados.rados_ioctx_pool_stat(handle, stat_s)
      end
      stat_s.to_hash
    end

    def flush_aio
      ensure_open
      CephRuby.rados_call('flush_aio') do
        Lib::Rados.rados_aio_flush(handle)
      end
    end
  end
end

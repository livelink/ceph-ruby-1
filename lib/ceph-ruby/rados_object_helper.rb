module CephRuby
  # Helper functions for Rados Object
  module RadosObjectHelper
    def size
      stat[:size]
    end

    def mtime
      stat[:mtime]
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

    def log(message)
      CephRuby.log("rados object #{pool.name}/#{name} #{message}")
    end
  end
end

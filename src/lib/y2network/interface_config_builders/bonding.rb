# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2network/config"
require "y2network/interface_config_builder"

module Y2Network
  module InterfaceConfigBuilders
    class Bonding < InterfaceConfigBuilder
      include Yast::Logger
      extend Forwardable

      def initialize(config: nil)
        super(type: InterfaceType::BONDING, config: config)
      end

      # @return [Array<Interface>] list of interfaces usable for the bond device
      def bondable_interfaces
        interfaces.select { |i| bondable?(i) }
      end

      def_delegators :connection_config,
        :slaves, :slaves=

      # @param value [String] options for bonding
      def bond_options=(value)
        connection_config.options = value
      end

      # current options for bonding
      # @return [String]
      def bond_options
        connection_config.options
      end

    private

      def interfaces
        Config.find(:yast).interfaces
      end

      # Checks whether an interface can be enslaved in particular bond interface
      #
      # @param iface [Interface] an interface to be validated as bond_iface slave
      # TODO: Check for valid configurations. E.g. bond device over vlan
      # is nonsense and is not supported by netconfig.
      # Also devices enslaved in a bridge should be excluded too.
      def bondable?(iface)
        Yast.import "Arch"
        Yast.include self, "network/lan/s390.rb"

        # check if the device is L2 capable on s390
        if Yast::Arch.s390
          s390_config = s390_ReadQethConfig(iface.name)

          # only devices with L2 support can be enslaved in bond. See bnc#719881
          return false unless s390_config["QETH_LAYER2"] == "yes"
        end

        config = yast_config.connections.by_name(iface.name)
        master = config.find_master(yast_config.connections)
        if master
          log.debug("Excluding (#{iface.name}) - already has master #{master.inspect}")
          return false
        end

        # cannot enslave itself
        return false if iface.name == @name

        return true unless yast_config.configured_interface?(iface.name)

        config.bootproto.to_s == "none"
      end
    end
  end
end

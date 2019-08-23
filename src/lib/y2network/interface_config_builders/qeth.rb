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
require "y2network/interface_config_builder"

Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  module InterfaceConfigBuilders
    # Builder for S390 qeth interfaces. It also assumes the activation
    # responsibilities.
    class Qeth < InterfaceConfigBuilder
      extend Forwardable

      # Constructor
      #
      # @param config [Y2Network::ConnectionConfig::Base, nil] existing configuration of device or nil
      #   for newly created
      def initialize(config: nil)
        super(type: InterfaceType::QETH, config: config)
      end

      def_delegators :@connection_config,
        :read_channel, :read_channel=,
        :write_channel, :write_channel=,
        :data_channel, :data_channel=,
        :layer2, :layer2=,
        :port_number, :port_number=,
        :lladdress, :lladdress=,
        :ipa_takeover, :ipa_takeover=,
        :attributes, :attributes=

      # @return [Array<String>]
      def configure_attributes
        return [] unless attributes

        attributes.split(" ")
      end

      # The device id to be used by lszdev or chzdev commands
      #
      # @return [String]
      def device_id
        return if read_channel.to_s.empty?

        [read_channel, write_channel, data_channel].join(":")
      end

      # Returns the complete device id which contains the given channel
      #
      # @param channel [String]
      # @return [String]
      def device_id_from(channel)
        cmd = "/sbin/lszdev qeth -c id -n".split(" ")

        Yast::Execute.stdout.on_target!(cmd).split("\n").find do |d|
          d.include? channel
        end
      end

      # It tries to enable the interface with the configured device id
      #
      # @return [Boolean] true when enabled
      def configure
        cmd = "/sbin/chzdev qeth #{device_id} -e".split(" ").concat(configure_attributes)

        Yast::Execute.on_target!(*cmd, allowed_exitstatus: 0..255).zero?
      end

      # Obtains the enabled interface name associated with the device id
      #
      # @return [String] device name
      def configured_interface
        cmd = "/sbin/lszdev #{device_id} -c names -n".split(" ").concat(configure_attributes)

        Yast::Execute.stdout.on_target!(cmd).chomp
      end

      # Modifies the read, write and data channel from the the device id
      def propose_channels
        id = device_id_from(hwinfo.busid)
        return unless id
        self.read_channel, self.write_channel, self.data_channel = id.split(":")
      end

      # Makes a new channels proposal only if not already set
      def proposal
        propose_channels unless device_id
      end
    end
  end
end

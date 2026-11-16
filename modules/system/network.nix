# systemd-networkd (DHCP on any wired/wireless link), iwd for Wi-Fi authentication,
# resolved with DNS-over-TLS + DNSSEC to Quad9, nftables firewall closed inbound.
{
  flake.modules.nixos.network =
    let
      # Never take DNS servers from DHCP/RA: all lookups go to the encrypted resolver below.
      noDhcpDns = {
        dhcpV4Config.UseDNS = false;
        dhcpV6Config.UseDNS = false;
        ipv6AcceptRAConfig.UseDNS = false;
      };
    in
    {
      networking = {
        useNetworkd = true;
        useDHCP = false;
        wireless.iwd.enable = true; # idle until a Wi-Fi adapter appears

        nftables.enable = true;
        firewall = {
          enable = true;
          allowPing = false;
        };
      };

      systemd.network = {
        enable = true;
        wait-online.anyInterface = true; # online as soon as one link is up
        networks = {
          "10-wired" = noDhcpDns // {
            matchConfig.Type = "ether";
            networkConfig = {
              DHCP = "yes";
              IPv6AcceptRA = true;
            };
          };
          "20-wireless" = noDhcpDns // {
            matchConfig.Type = "wlan";
            networkConfig = {
              DHCP = "yes";
              IPv6AcceptRA = true;
            };
          };
        };
      };

      services.resolved = {
        enable = true;
        settings.Resolve = {
          DNS = [
            "9.9.9.9#dns.quad9.net"
            "149.112.112.112#dns.quad9.net"
            "2620:fe::fe#dns.quad9.net"
            "2620:fe::9#dns.quad9.net"
          ];
          Domains = [ "~." ]; # route every lookup to the servers above
          DNSOverTLS = true;
          DNSSEC = true;
          FallbackDNS = [ ]; # no silent plaintext fallback
          LLMNR = false;
          MulticastDNS = false;
        };
      };
    };
}

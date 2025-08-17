# 🦌 OxlVPN

**Simple, free CLI VPN for peeps who just want things to work.**

Made for devs, cybersec enthusiasts, and anyone who values their digital freedom. No corporate BS, no paid tiers, no tracking - just a straightforward tool that does what it says.

## Here we go

```bash
# Make it executable (first time only)
chmod +x oxl.sh

# Launch the magic
./oxl.sh
```

That's it.

## What Does It Do?

- **Free VPN servers worldwide** - We scan for working free VPN endpoints
- **Multi-hop connections** - Chain multiple VPNs for extra paranoia
- **Real-time traffic stats** - See exactly how much data you're pushing
- **Auto-cleanup** - No leftover connections when you exit
- **Human interface** - ASCII art because terminal apps should be fun

## Features

### The Good Stuff
- **Zero configuration** - Just run it
- **Multiple protocols** - OpenVPN, WireGuard support
- **Live ping testing** - Shows you the fastest servers
- **Session monitoring** - Track your upload/download in real-time
- **Clean exits** - Always disconnects properly when you quit

### The Honest Truth
These are **free VPNs**. They're great for:
- Getting around geo-blocks
- P2P downloads
- General privacy from your ISP
- Testing and development

They're **not great for**:
- Highly sensitive data (use paid VPNs for that)
- Mission-critical privacy (again, pay for quality)
- Illegal activities (don't be that person)

## Requirements

Basic Linux tools (usually pre-installed):
- `curl` - For IP checking and server communication
- `ping` - For latency testing
- `bc` - For traffic calculations

Tools you HAVE to install:
- `openvpn` - For actually connecting with VPNs

Install tools:
```bash
sudo apt install curl iputils-ping bc openvpn
```

Enable & Start OpenVPN:
```bash
sudo systemctl start openvpn
sudo systemctl enable openvpn
sudo systemctl status openvpn
```
And you should see its working.

## Contributing

Found a bug? Want to add a feature? Cool.

1. Fork it
2. Make it better
3. Send a pull request
4. Include a good commit message

No fancy contribution guidelines - just make it work and don't break existing stuff pls.

## Legal Stuff

This tool is for educational and legitimate use only. You're responsible for:
- Following your local laws
- Respecting VPN providers' terms
- Not being a digital menace

We're not responsible if you use this for shady stuff.

## Roadmap

- [X] Real VPN provider integration
- [ ] Config file support
- [ ] Automatic server health checks
- [ ] Kill switch functionality
- [ ] DNS leak protection

## Support

Having trouble? Check if your issue is already reported in the GitHub issues. If not, open a new one with:
- What you were trying to do
- What happened instead
- Your OS and any error messages

## License

MIT License - Do whatever you want with this code, just don't blame us if it breaks something.

---

**Made with ❤️ by humans who believe the internet should be free and open.**

*Stay anonymous, stay free.* 🔒
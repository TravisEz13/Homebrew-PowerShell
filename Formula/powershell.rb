# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
class Powershell < Formula
  desc "PowerShell"
  homepage "https://github.com/powershell/powershell"
  # We do not specify `version "..."` as 'brew audit' will complain - see https://github.com/Homebrew/legacy-homebrew/issues/32540
  url "https://github.com/PowerShell/PowerShell/releases/download/v7.0.0/powershell-7.0.0-osx-x64.tar.gz"
  # must be lower-case
  sha256 "7ea2a539cb33f3c1c62280eea1d3b55cbd84c86676437a390e81c0ae374483e6"
  bottle :unneeded

  # .NET Core 3.1 requires High Sierra - https://docs.microsoft.com/en-us/dotnet/core/install/dependencies?pivots=os-macos&tabs=netcore31
  depends_on :macos => :high_sierra

  conflicts_with :cask => "powershell"

  def install
    libexec.install Dir["*"]
    chmod 0555, libexec/"pwsh"
    bin.install_symlink libexec/"pwsh"
  end

  def caveats
    <<~EOS
      The executable should already be on PATH so run with `pwsh`. If not, the full path to the executable is:
        #{bin}/pwsh

      Other application files were installed at:
        #{libexec}
    EOS
  end

  test do
    system bin/"pwsh", "-v"
    system bin/"pwsh", "-c", "$psversiontable.psversion.tostring()"
  end
end

# Builds FlipThePancake.rbxlx from the scripts folder.
# Run it again after editing any .lua file, then reopen the .rbxlx in Studio.

$dir = "C:\Users\andrew\Desktop\FlipThePancake"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Where each script goes: file, Roblox class, name in Studio, parent service
$scripts = @(
	@{ File = "GameConfig.lua";                Class = "ModuleScript"; Name = "GameConfig";        Parent = "ReplicatedStorage" },
	@{ File = "PanConfig.lua";                 Class = "ModuleScript"; Name = "PanConfig";         Parent = "ReplicatedStorage" },
	@{ File = "SizeConfig.lua";                Class = "ModuleScript"; Name = "SizeConfig";        Parent = "ReplicatedStorage" },
	@{ File = "PancakeConfig.lua";             Class = "ModuleScript"; Name = "PancakeConfig";     Parent = "ReplicatedStorage" },
	@{ File = "ToppingConfig.lua";             Class = "ModuleScript"; Name = "ToppingConfig";     Parent = "ReplicatedStorage" },
	@{ File = "PancakeVisuals.lua";            Class = "ModuleScript"; Name = "PancakeVisuals";    Parent = "ReplicatedStorage" },
	@{ File = "UIStyle.lua";                   Class = "ModuleScript"; Name = "UIStyle";           Parent = "ReplicatedStorage" },
	@{ File = "PancakeServer.server.lua";      Class = "Script";       Name = "PancakeServer";     Parent = "ServerScriptService" },
	@{ File = "DataManager.lua";               Class = "ModuleScript"; Name = "DataManager";       Parent = "ServerScriptService" },
	@{ File = "EventManager.lua";              Class = "ModuleScript"; Name = "EventManager";      Parent = "ServerScriptService" },
	@{ File = "OrderManager.lua";              Class = "ModuleScript"; Name = "OrderManager";      Parent = "ServerScriptService" },
	@{ File = "WorldBuilder.lua";              Class = "ModuleScript"; Name = "WorldBuilder";      Parent = "ServerScriptService" },
	@{ File = "CookingController.client.lua";  Class = "LocalScript";  Name = "CookingController"; Parent = "StarterPlayerScripts" },
	@{ File = "ShopController.client.lua";     Class = "LocalScript";  Name = "ShopController";    Parent = "StarterPlayerScripts" },
	@{ File = "RushHourController.client.lua"; Class = "LocalScript";  Name = "RushHourController"; Parent = "StarterPlayerScripts" },
	@{ File = "Effects.lua";                   Class = "ModuleScript"; Name = "Effects";           Parent = "StarterPlayerScripts" }
)

# Keep any models installed with InstallAssets.txt (ReplicatedStorage > Assets) when rebuilding
$assetsXml = ""
$sharedXml = ""
$existing = "$dir\FlipThePancake.rbxlx"
if (Test-Path $existing) {
	try {
		$old = New-Object System.Xml.XmlDocument
		$old.Load($existing)
		$folder = $old.SelectSingleNode("//Item[@class='ReplicatedStorage']/Item[@class='Folder'][Properties/string[@name='Name']='Assets']")
		if ($folder) {
			$assetsXml = $folder.OuterXml
			# meshes saved by Studio keep their data in a SharedStrings section at the end of the file
			$shared = $old.SelectSingleNode("/roblox/SharedStrings")
			if ($shared) { $sharedXml = $shared.OuterXml }
			"Keeping installed Assets folder (" + $folder.SelectNodes("Item").Count + " models)"
		}
	} catch { "Couldn't read the old place file, installed models not kept: $_" }
}

$ref = 100
function ScriptItems($parentName) {
	$out = ""
	foreach ($s in $scripts | Where-Object { $_.Parent -eq $parentName }) {
		$script:ref++
		$src = [System.Security.SecurityElement]::Escape([IO.File]::ReadAllText("$dir\scripts\$($s.File)", $utf8))
		$out += "<Item class=`"$($s.Class)`" referent=`"RBX$script:ref`"><Properties><string name=`"Name`">$($s.Name)</string><ProtectedString name=`"Source`">$src</ProtectedString></Properties></Item>`n"
	}
	return $out
}
function Col($r, $g, $b) { [uint32](4278190080 + $r * 65536 + $g * 256 + $b) }
function CF($x, $y, $z) { "<X>$x</X><Y>$y</Y><Z>$z</Z><R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12><R20>0</R20><R21>0</R21><R22>1</R22>" }

$xml = @"
<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
	<Item class="Workspace" referent="RBX0">
		<Properties><string name="Name">Workspace</string></Properties>
		<Item class="SpawnLocation" referent="RBX2">
			<Properties>
				<string name="Name">SpawnLocation</string>
				<bool name="Anchored">true</bool>
				<bool name="Neutral">true</bool>
				<CoordinateFrame name="CFrame">$(CF 0 0.68 194)</CoordinateFrame>
				<Vector3 name="size"><X>12</X><Y>1</Y><Z>12</Z></Vector3>
				<Color3uint8 name="Color3uint8">$(Col 255 205 80)</Color3uint8>
				<token name="TopSurface">0</token>
				<token name="BottomSurface">0</token>
			</Properties>
		</Item>
	</Item>
	<Item class="ReplicatedStorage" referent="RBX3">
		<Properties><string name="Name">ReplicatedStorage</string></Properties>
		$(ScriptItems "ReplicatedStorage")
		$assetsXml
	</Item>
	<Item class="ServerScriptService" referent="RBX5">
		<Properties><string name="Name">ServerScriptService</string></Properties>
		$(ScriptItems "ServerScriptService")
	</Item>
	<Item class="StarterPlayer" referent="RBX7">
		<Properties><string name="Name">StarterPlayer</string></Properties>
		<Item class="StarterPlayerScripts" referent="RBX8">
			<Properties><string name="Name">StarterPlayerScripts</string></Properties>
			$(ScriptItems "StarterPlayerScripts")
		</Item>
	</Item>
	$sharedXml
</roblox>
"@

$out = "$dir\FlipThePancake.rbxlx"
[IO.File]::WriteAllText($out, $xml, $utf8)
$doc = New-Object System.Xml.XmlDocument
$doc.Load($out)
"Built $out (" + [math]::Round((Get-Item $out).Length / 1KB, 1) + " KB), XML valid, " + $scripts.Count + " scripts"

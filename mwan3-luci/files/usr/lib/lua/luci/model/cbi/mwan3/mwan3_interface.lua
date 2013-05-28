local ds = require "luci.dispatcher"

function metriclist()
	-- create list of interface metrics to compare against for duplicates and blanks
	uci.cursor():foreach("mwan3", "interface",
		function (section)
			ifnum = ifnum+1
			local metlkp = luci.sys.exec("uci get -p /var/state network." .. section[".name"] .. ".metric")
			if string.len(metlkp) == 0 then
				metlkp = "none"
			end
			metlst = metlst .. metlkp .. " "
		end
	)
	metlst = luci.sys.exec("echo \"" .. metlst .. "\" | sed 's/^[ \t]*//;s/[ \t]*$//' | tr \' \' \'\n\' | sed '/^$/d'")
	-- determine if blanks exist
	metnone = luci.sys.exec("echo \"" .. metlst .. "\" | grep -c none")
		metnone = string.gsub(metnone, "\n", "")
		if metnone ~= "0" then
			metnone = 1
		end
	-- determine if duplicates exist
	metdup = luci.sys.exec("echo \"" .. metlst .. "\" | sed 's/^[ \t]*//;s/[ \t]*$//' | tr \" \" \"\n\" | grep -v none | sed '/^$/d' | uniq -c | grep -v \" 1 \"")
luci.sys.exec("echo \"" .. metdup .. "\" > /tmp/cock")
		if string.len(metdup) > 0 then
			metdup = 1
		end
end

function ifacewarn()
	-- display status and warning messages at the top of the page
	local warns = ""
	if ifnum <= 15 then
		warns = "<strong><em>There are currently " .. ifnum .. " of 15 supported interfaces configured!</em></strong>"
	else
		warns = "<font color=\"ff0000\"><strong><em>WARNING: " .. ifnum .. " interfaces are configured exceeding the maximum of 15!</em></strong></font>"
	end
	if metnone == 1 then
		warns = warns .. "<br /><br /><font color=\"ff0000\"><strong><em>WARNING: some interfaces have no metric configured in /etc/config/network!</em></strong></font>"
	end
	if metdup == 1 then
		warns = warns .. "<br /><br /><font color=\"ff0000\"><strong><em>WARNING: some interfaces have duplicate metrics configured in /etc/config/network!</em></strong></font>"
	end
	return warns
end

-- ------ interface configuration ------ --

ifnum = 0
metlst = ""
metnone = ""
metdup = ""
metriclist()


m5 = Map("mwan3", translate("MWAN3 Multi-WAN Interface Configuration"),
	translate(ifacewarn()))


mwan_interface = m5:section(TypedSection, "interface", translate("Interfaces"),
	translate("MWAN3 supports up to 15 physical and/or logical interfaces<br />") ..
	translate("MWAN3 requires that all interfaces have a unique metric configured in /etc/config/network<br />") ..
	translate("Name must match the interface name found in /etc/config/network (see troubleshooting tab)<br />") ..
	translate("Name may contain characters A-Z, a-z, 0-9, _ and no spaces<br />") ..
	translate("Interfaces may not share the same name as configured members, policies or rules"))
	mwan_interface.addremove = true
	mwan_interface.dynamic = false
	mwan_interface.sortable = false
	mwan_interface.template = "cbi/tblsection"
	mwan_interface.extedit = ds.build_url("admin", "network", "mwan3", "interface", "%s")

	function mwan_interface.create(self, section)
		TypedSection.create(self, section)
		m5.uci:save("mwan3")
		luci.http.redirect(ds.build_url("admin", "network", "mwan3", "interface", section))
	end


enabled = mwan_interface:option(DummyValue, "enabled", translate("Enabled"))
	enabled.rawhtml = true
	function enabled.cfgvalue(self, s)
		enbld = self.map:get(s, "enabled")
		if enbld == "1" then
			return "<br />Yes<br /><br />"
		else
			return "<br />No<br /><br />"
		end
	end

track_ip = mwan_interface:option(DummyValue, "track_ip", translate("Test IP"))
	track_ip.rawhtml = true
	function track_ip.cfgvalue(self, s)
		local str = "<br />"
		local tab = self.map:get(s, "track_ip")
		if tab then
			for k,v in pairs(tab) do
				str = str .. v .. "<br />"
			end
		else
			str = "<br /><font size=\"+4\">-</font>"
		end
		str = str .. "<br />"
		return str
	end

reliability = mwan_interface:option(DummyValue, "reliability", translate("Test IP reliability"))
	reliability.rawhtml = true
	function reliability.cfgvalue(self, s)
		return self.map:get(s, "reliability") or "<br /><font size=\"+4\">-</font>"
	end

count = mwan_interface:option(DummyValue, "count", translate("Ping count"))
	count.rawhtml = true
	function count.cfgvalue(self, s)
		return self.map:get(s, "count") or "<br /><font size=\"+4\">-</font>"
	end

timeout = mwan_interface:option(DummyValue, "timeout", translate("Ping timeout"))
	timeout.rawhtml = true
	function timeout.cfgvalue(self, s)
		local tcheck = self.map:get(s, "timeout")
		if tcheck then
			tcheck = tcheck .. "s"
		else
			tcheck = "<br /><font size=\"+4\">-</font>"
		end
		return tcheck
	end

interval = mwan_interface:option(DummyValue, "interval", translate("Ping interval"))
	interval.rawhtml = true
	function interval.cfgvalue(self, s)
		local icheck = self.map:get(s, "interval")
		if icheck then
			icheck = icheck .. "s"
		else
			icheck = "<br /><font size=\"+4\">-</font>"
		end
		return icheck
	end

down = mwan_interface:option(DummyValue, "down", translate("Interface down"))
	down.rawhtml = true
	function down.cfgvalue(self, s)
		return self.map:get(s, "down") or "<br /><font size=\"+4\">-</font>"
	end

up = mwan_interface:option(DummyValue, "up", translate("Interface up"))
	up.rawhtml = true
	function up.cfgvalue(self, s)
		return self.map:get(s, "up") or "<br /><font size=\"+4\">-</font>"
	end

metric = mwan_interface:option(DummyValue, "metric", translate("Metric"))
	metric.rawhtml = true
	function metric.cfgvalue(self, s)
		local metcheck = luci.sys.exec("uci get -p /var/state network." .. s .. ".metric")
		if string.len(metcheck) > 0 then
			metcheck = string.gsub(metcheck, "\n", "")
			local dupcheck = luci.sys.exec("echo \"" .. metlst .. "\" | grep -c \"" .. metcheck .. "\"")
				dupcheck = string.gsub(dupcheck, "\n", "")
			if dupcheck ~= "1" then
				metcheck = "<font color=\"ff0000\"><strong>" .. metcheck .. "</strong></font>"
			end
		else
			metcheck = "<br /><font color=\"ff0000\"><font size=\"+4\">-</font></font>"
		end
		return metcheck
	end


return m5

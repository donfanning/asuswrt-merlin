﻿<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<html xmlns:v>
<head>
<meta http-equiv="X-UA-Compatible" content="IE=edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
<meta HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title><#Web_Title#> - Switch Control</title>
<link rel="stylesheet" type="text/css" href="index_style.css"> 
<link rel="stylesheet" type="text/css" href="form_style.css">
<link rel="stylesheet" type="text/css" href="other.css">
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script type="text/javascript" src="/detect.js"></script>

<script>
var wireless = [<% wl_auth_list(); %>];	// [[MAC, associated, authorized], ...]
var ctf_support = ('<% nvram_get("ctf_fa_mode"); %>' == '') ? 0 : 1;
var ctf_fa_cap = "<% nvram_get("ctf_fa_cap"); %>";

function initial(){
	show_menu();

	document.form.ctf_level.length = 0;
	if(ctf_support == 1){
		add_option(document.form.ctf_level, "<#WLANConfig11b_WirelessCtrl_buttonname#>", 0, getCtfLevel(0));
		add_option(document.form.ctf_level, "Level 1 CTF", 1, getCtfLevel(1));
		if(ctf_fa_cap == 1)
			add_option(document.form.ctf_level, "Level 2 CTF", 2, getCtfLevel(2));
	} else {
		add_option(document.form.ctf_level, "<#WLANConfig11b_WirelessCtrl_buttonname#>", 0, getCtfLevelM(0));
		add_option(document.form.ctf_level, "<#WLANConfig11b_WirelessCtrl_button1name#>", 1, getCtfLevelM(1));
	}
	
	update_ctf_status();
}

function getCtfLevel(val){
	var curVal;

	if(document.form.ctf_disable_force.value == 0){
		if(document.form.ctf_fa_mode.value == 2)
			curVal = 2;
		else
			curVal = 1;
	} else
		curval = 0;

	if(curVal == val)
		return true;
	else
		return false;
}

function getCtfLevelM(val){
	var curVal;

	if(document.form.ctf_disable_force.value == 0)
		curVal = 1;
	else
		curVal = 0;

	if(curVal == val)
		return true;
	else
		return false;
}

function applyRule(){
	if(document.form.ctf_level.value == 1 || document.form.ctf_level.value ==2){
		document.form.ctf_disable_force.value = 0;
		if(ctf_support == 1)
			document.form.ctf_fa_mode.value = document.form.ctf_level.value;
	}
	else {
		document.form.ctf_disable_force.value = 1;
		if(ctf_support == 1)
			document.form.ctf_fa_mode.value = 0;
	}

	if(valid_form()){
			document.form.action_wait.value = Math.max(eval("<% get_default_reboot_time(); %>"), 90);
			showLoading();
			document.form.submit();	
	}
}

function update_ctf_status(){
	if(document.form.ctf_disable.value == 1 && document.form.ctf_level.value != 0){
		var code = "<B>Disabled</B>"
		code += " <i> - incompatible with:&nbsp;&nbsp;";	// Two trailing spaces
		if ('<% nvram_get("cstats_enable"); %>' == '1') code += 'IPTraffic, ';
		if ('<% nvram_get("qos_enable"); %>' == '1') code += 'QoS, ';
		if ('<% nvram_get("sw_mode"); %>' == '2') code += 'Repeater mode, ';
		if ('<% nvram_get("ctf_disable_modem"); %>' == '1') code += 'USB modem, ';

		// We're disabled but we don't know why
		if (code.slice(-6) == "&nbsp;") code += "&lt;unknown&gt;, ";

		// Trim two trailing chars ", "
		code = code.slice(0,-2) + "</i>";
		document.getElementById("ctfLevelDesc").innerHTML = code;
		document.getElementById("ctf_level").style.display = "none";
	}
	else {
		document.getElementById("ctfLevelDesc").innerHTML = "";
		document.getElementById("ctf_level").style.display = "";
	}
}

function valid_form(){		
	return true;	
}

</script>
</head>

<body onload="initial();" onunLoad="return unload_body();">
<div id="TopBanner"></div>
<div id="hiddenMask" class="popup_bg">
	<table cellpadding="5" cellspacing="0" id="dr_sweet_advise" class="dr_sweet_advise" align="center">
		<tr>
		<td>
			<div class="drword" id="drword" style="height:110px;"><#Main_alert_proceeding_desc4#>&nbsp;<#Main_alert_proceeding_desc1#>...
				<br/>
				<br/>
	    </div>
		  <div class="drImg"><img src="images/alertImg.png"></div>
			<div style="height:70px;"></div>
		</td>
		</tr>
	</table>
<!--[if lte IE 6.5]><iframe class="hackiframe"></iframe><![endif]-->
</div>

<div id="Loading" class="popup_bg"></div>

<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

<form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="productid" value="<% nvram_get("productid"); %>">
<input type="hidden" name="current_page" value="Advanced_SwitchCtrl_Content.asp">
<input type="hidden" name="next_page" value="Advanced_SwitchCtrl_Content.asp">
<input type="hidden" name="group_id" value="">
<input type="hidden" name="modified" value="0">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_script" value="reboot">
<input type="hidden" name="action_wait" value="90">
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>">
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>">
<input type="hidden" name="ctf_fa_mode" value="<% nvram_get("ctf_fa_mode"); %>">
<input type="hidden" name="ctf_disable_force" value="<% nvram_get("ctf_disable_force"); %>">
<input type="hidden" name="ctf_disable" value="<% nvram_get("ctf_disable"); %>">

<table class="content" align="center" cellpadding="0" cellspacing="0">
  <tr>
	<td width="17">&nbsp;</td>
	
	<!--=====Beginning of Main Menu=====-->
	<td valign="top" width="202">
	  <div id="mainMenu"></div>
	  <div id="subMenu"></div>
	</td>
	
    <td valign="top">
	<div id="tabMenu" class="submenuBlock"></div>
		<!--===================================Beginning of Main Content===========================================-->
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
	<tr>
		<td align="left" valign="top">
  <table width="760px" border="0" cellpadding="5" cellspacing="0" class="FormTitle" id="FormTitle">
	<tbody>
	<tr>
		  <td bgcolor="#4D595D" valign="top">
		  <div>&nbsp;</div>
		  <div class="formfonttitle"><#menu5_2#> - Switch Control</div>
      <div style="margin-left:5px;margin-top:10px;margin-bottom:10px"><img src="/images/New_ui/export/line_export.png"></div>
      <div class="formfontdesc">Setting <#Web_Title2#> switch control.</div>
		  
		  <table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3"  class="FormTable">
      <tr>
      <th><!--a class="hintstyle" href="javascript:void(0);" onClick="openHint(4,4);"--><#jumbo_frame#><!--/a--></th>
          <td>
						<select name="jumbo_frame_enable" class="input_option">
							<option class="content_input_fd" value="0" <% nvram_match("jumbo_frame_enable", "0","selected"); %>><#WLANConfig11b_WirelessCtrl_buttonname#></option>
							<option class="content_input_fd" value="1" <% nvram_match("jumbo_frame_enable", "1","selected"); %>><#WLANConfig11b_WirelessCtrl_button1name#></option>
						</select>
          </td>
      </tr>
      <tr>
      <th>NAT Acceleration</th>
          <td>
						<select name="ctf_level" id="ctf_level" class="input_option">
							<option class="content_input_fd" value="0" "<% nvram_match("ctf_disable_force", "1","selected"); %>><#WLANConfig11b_WirelessCtrl_buttonname#></option>
							<option class="content_input_fd" value="1" <% nvram_match("ctf_disable_force", "0","selected"); %>><#WLANConfig11b_WirelessCtrl_button1name#></option>
						</select>
						<span id="ctfLevelDesc"></span>
          </td>
      </tr>     
	    <tr style="display:none">
	      <th>Enable GRO(Generic Receive Offload)</th>
 	          <td>
	              <input type="radio" name="gro_disable_force" value="0" <% nvram_match("gro_disable_force", "0", "checked"); %>><#checkbox_Yes#>
	              <input type="radio" name="gro_disable_force" value="1" <% nvram_match("gro_disable_force", "1", "checked"); %>><#checkbox_No#>
 	          </td>
	      </tr>
      <tr>
          <th>Spanning-Tree Protocol</th>
              <td>
				                <select name="lan_stp" class="input_option">
						        <option class="content_input_fd" value="0" <% nvram_match("lan_stp", "0","selected"); %>><#WLANConfig11b_WirelessCtrl_buttonname#></option>
						        <option class="content_input_fd" value="1" <% nvram_match("lan_stp", "1","selected"); %>><#WLANConfig11b_WirelessCtrl_button1name#></option>
                                                </select>
              </td>
      </tr>

			</table>	

		<div class="apply_gen">
			<input class="button_gen" onclick="applyRule()" type="button" value="<#CTL_apply#>"/>
		</div>
		
	  </td>
	</tr>

	</tbody>	
  </table>		
					
		</td>
	</form>					
				</tr>
			</table>				
			<!--===================================End of Main Content===========================================-->
</td>

    <td width="10" align="center" valign="top">&nbsp;</td>
	</tr>
</table>

<div id="footer"></div>
</body>
</html>

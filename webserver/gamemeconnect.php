<?php
$account = "null";
$game = "null";
$sid = "null";
function checkVariable(&$var, $attrib) {
	if(isset($_POST[$attrib])) {
		$var = $_POST[$attrib];
	} else if(isset($_GET[$attrib])) {
		$var = $_GET[$attrib];
	} else {
		print('"error""Unable to get attrib: '.$attrib.'"');
		return false;
	}
	return true;
}

print("\"gmc\"{");
if(checkVariable($account, 'a') 
	&& checkVariable($game, 'g')
	&& checkVariable($sid, 'id')) {
	$url = "http://".$account.".gameme.com/api/playerinfo/".$game."/".$sid;
	$xml = new SimpleXMLElement(file_get_contents($url));
	if(count($xml->playerinfo[0]->player) <= 0) {
	  print("\"error\"\"Player not in database\"");
	} else {
	  $name = "";
	  foreach($xml->playerinfo[0]->player[0] as $Item){
		$name = $Item->getName();
		if((isset($_POST[$name]) || isset($_GET[$name])) && $name != "id") {
		  print("\"".$name."\"\"".$Item."\"");
		}
	  }
	}
}
print("}");
?>
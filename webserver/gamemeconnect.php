<?php
$account = "null";
$game = "null";
$sid = "null";
if(isset($_POST['a'])) {
	$account = $_POST['a'];
} else if(isset($_GET['a'])) {
	$account = $_GET['a'];
} else {
	print('error: Unable to get variable: "account"');
	return;
}
if(isset($_POST['g'])) {
	$game =    $_POST['g'];
} else if(isset($_GET['g'])) {
	$game =     $_GET['g'];
} else {
	print('error: Unable to get variable: "game"');
	return;
}
if(isset($_POST['id'])) {
	$sid =     $_POST['id'];
} else if(isset($_GET['id'])) {
	$sid =      $_GET['id'];
} else {
	print('error: Unable to get variable: "sid"');
	return;
}
$url = "http://".$account.".gameme.com/api/playerinfo/".$game."/".$sid;
$xml = new SimpleXMLElement(file_get_contents($url));
if(count($xml->playerinfo[0]->player) <= 0) {
	print("error: invalid player info (".$sid.")");
} else {
  $name = "";
  print("\"gmc\"{");
  foreach($xml->playerinfo[0]->player[0] as $Item){
    $name = $Item->getName();
    if((isset($_POST[$name]) || isset($_GET[$name])) && $name != "id") {
      print("\"".$name."\"\"".$Item."\"");
    }
  }
  print("}");
}
?>
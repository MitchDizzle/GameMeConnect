<?php
$account = isset($_POST['a']) ? $_POST['a']: $_GET['a'];
$game = isset($_POST['g']) ? $_POST['g']: $_GET['g'];
$sid = isset($_POST['id']) ? $_POST['id']: $_GET['id'];
$url = "http://".$account.".gameme.com/api/playerinfo/".$game."/".$sid;
$xml = new SimpleXMLElement(file_get_contents($url));
if(count($xml->playerinfo[0]->player) <= 0) {
	print("error");
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
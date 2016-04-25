<?php
$account = isset($_POST['a']) ? $_POST['a']: $_GET['a'];
$game = isset($_POST['g']) ? $_POST['g']: $_GET['g'];
$sid = isset($_POST['id']) ? $_POST['id']: $_GET['id'];
$showid = isset($_POST['showid']);
$url = "http://".$account.".gameme.com/api/playerinfo/".$game."/".$sid;
$xml = new SimpleXMLElement(file_get_contents($url));
if(count($xml->playerinfo[0]->player) > 0) {
  if($showid) print($xml->playerinfo[0]->player[0]->uniqueid.";");
  print($xml->playerinfo[0]->player[0]->rank.";");
  print($xml->playerinfo[0]->player[0]->time.";");
  print($xml->playerinfo[0]->player[0]->kills.";");
  print($xml->playerinfo[0]->player[0]->deaths.";");
  print($xml->playerinfo[0]->player[0]->assists);
} else {
  print("error");
}
?>
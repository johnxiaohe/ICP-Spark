import Trie "mo:base/Trie";
import Text "mo:base/Text";

type Trie<K, V> = Trie.Trie<K, V>;
type Key<K> = Trie.Key<K>;

func textKey(t: Text) : Key<Text> { { hash = Text.hash t; key = t } };
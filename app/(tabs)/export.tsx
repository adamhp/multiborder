import { FontAwesome } from '@expo/vector-icons';
import { useCallback, useState } from 'react';
import {
  ActivityIndicator,
  Linking,
  Text,
  View,
  Image,
  Alert,
  Pressable
} from 'react-native';
import { TouchableHighlight } from 'react-native';
import Toast from 'react-native-toast-message';
import { useRecoilValue } from 'recoil';
import { captureFunctionsState, imagesState } from '../../lib/state';
import { PageContainer } from './_layout';
import { usePermissions } from 'expo-media-library';

export default function ExportScreen() {
  const captureFunctions = useRecoilValue(captureFunctionsState);
  const handlePress = useCallback(async (url: string) => {
    // Checking if the link is supported for links with custom URL scheme.
    const supported = await Linking.canOpenURL(url);

    if (supported) {
      // Opening the link with some app, if the URL scheme is "http" the web link should be opened
      // by some browser in the mobile
      await Linking.openURL(url);
    } else {
      Alert.alert(`Don't know how to open this URL: ${url}`);
    }
  }, []);

  return (
    <PageContainer>
      <SizeActions captureFunctions={captureFunctions} size={1024} />
      <SizeActions captureFunctions={captureFunctions} size={2048} />
      <SizeActions captureFunctions={captureFunctions} size={4096} />
      <SizeActions captureFunctions={captureFunctions} size="original" />
      <Pressable
        onPress={() => {
          handlePress('https://ko-fi.com/adamhp');
        }}
        className="mt-12 object-contain h-10 w-full"
      >
        <Image
          style={{ width: '100%', height: '100%', objectFit: 'contain' }}
          source={require('../../assets/images/kofi_button_dark.png')}
        />
      </Pressable>
    </PageContainer>
  );
}

function SizeActions({
  size = 1024,
  captureFunctions
}: {
  size: number | string;
  captureFunctions: Record<string, Function>;
}) {
  const [permissions, requestPermissions] = usePermissions();
  const images = useRecoilValue(imagesState);
  const [loading, setLoading] = useState(false);
  return (
    <View className="flex flex-row w-full justify-evenly items-center m-2">
      <View className="w-40 h-16 border-2 border-zinc-700 rounded-lg flex items-center justify-center p-2">
        <Text className="text-white font-space">
          {size === 'original' ? 'Original' : `${size}px`}
        </Text>
      </View>
      <TouchableHighlight
        className="w-16 h-16 bg-zinc-700 rounded-lg flex items-center justify-center p-2"
        onPress={() => {
          if (!permissions?.granted && permissions?.canAskAgain) {
            requestPermissions();
          }
          setLoading(true);
          Promise.all(
            Object.entries(captureFunctions).map(
              ([k, func]: [k: string, func: Function]) => {
                func(size);
              }
            )
          )
            .then(() => {
              setLoading(false);
              Toast.show({
                type: 'success',
                text1: `Saved ${images.length} ${
                  images.length === 1 ? 'image' : 'images'
                }!`
              });
            })
            .catch((e) => {
              setLoading(false);
              console.error(e);
              Toast.show({
                type: 'error',
                text1: 'Failed to save images...'
              });
            });
          setLoading(false);
        }}
      >
        {loading ? (
          <ActivityIndicator />
        ) : (
          <FontAwesome name="download" size={20} color="white" />
        )}
      </TouchableHighlight>
    </View>
  );
}

import { FontAwesome } from '@expo/vector-icons';
import { useState } from 'react';
import { ActivityIndicator, Text, View } from 'react-native';
import { TouchableHighlight } from 'react-native-gesture-handler';
import Toast from 'react-native-toast-message';
import { useRecoilValue } from 'recoil';
import { captureFunctionsState, imagesState } from '../../lib/state';
import { PageContainer } from './_layout';

export default function ExportScreen() {
  const captureFunctions = useRecoilValue(captureFunctionsState);
  return (
    <PageContainer>
      <SizeActions captureFunctions={captureFunctions} size={1024} />
      <SizeActions captureFunctions={captureFunctions} size={2048} />
      <SizeActions captureFunctions={captureFunctions} size={4096} />
      <SizeActions captureFunctions={captureFunctions} size="original" />
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

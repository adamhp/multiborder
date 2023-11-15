import { ScrollView, View, Text } from 'react-native';
import { useRecoilState, useRecoilValue } from 'recoil';
import { ImageThumbnailPost } from '../../components/ImageThumbnail';
import { imagesState, settingsState } from '../../lib/state';
import { PageContainer } from './_layout';
import { Slider } from '@miblanchard/react-native-slider';
import { useEffect, useState } from 'react';
import { useDebounce } from '../../lib/util';

export default function EditScreen() {
  const [settings, setSettings] = useRecoilState(settingsState);
  const images = useRecoilValue(imagesState);
  const [borderSize, setBorderSize] = useState([settings.borderSize]);

  const setBorder = useDebounce(() => {
    setSettings((oldSettings) => ({
      ...oldSettings,
      borderSize: borderSize[0]
    }));
  }, 500);

  useEffect(() => {
    setBorder();
  }, [borderSize]);

  return (
    <PageContainer>
      <ScrollView
        horizontal={true}
        decelerationRate={0}
        snapToInterval={settings.desiredSize * settings.desiredAspectRatio + 32}
        snapToAlignment={'center'}
        className="h-2/3"
      >
        {images.length > 0 &&
          images.map((image) => (
            <View key={image.uri} className="mx-4">
              <ImageThumbnailPost borderSize={borderSize[0]} item={image} />
            </View>
          ))}
      </ScrollView>
      <View className="flex flex-col h-1/3 rounded-lg bg-zinc-800 w-full px-4">
        <View className="flex flex-row items-center h-16">
          <View className="w-1/3">
            <Text className="text-white text-lg">Border Size:</Text>
          </View>
          <View className="relative flex w-2/3 justify-center">
            <Text className="absolute text-center inset-x-0 -top-1.5 font-space mx-auto text-white -mb-3">
              {borderSize}
            </Text>
            <Slider
              step={1}
              trackClickable={true}
              minimumValue={0}
              maximumValue={32}
              minimumTrackTintColor="#b45309"
              thumbTintColor="#b45309"
              value={borderSize}
              onValueChange={setBorderSize}
            />
          </View>
        </View>
      </View>
    </PageContainer>
  );
}

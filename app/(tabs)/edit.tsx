import { ScrollView, View, Text } from 'react-native';
import { useRecoilState, useRecoilValue } from 'recoil';
import { ImageThumbnailPost } from '../../components/ImageThumbnail';
import { imagesState, settingsState } from '../../lib/state';
import { PageContainer } from './_layout';
import { Slider } from '@miblanchard/react-native-slider';
import { useEffect, useState } from 'react';
import { useDebounce } from '../../lib/util';
import { FontAwesome } from '@expo/vector-icons';

import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { TriangleColorPicker, fromHsv } from 'react-native-color-picker';

const aspectRatios = ['1:1', '4:5', '16:9'];
export default function EditScreen() {
  const [settings, setSettings] = useRecoilState(settingsState);
  const images = useRecoilValue(imagesState);
  const [borderSize, setBorderSize] = useState([settings.borderSize]);
  const [aspectRatio, setAspectRatio] = useState(settings.desiredAspectRatio);
  const [borderColor, setBorderColorState] = useState(settings.borderColor);

  const setBorder = useDebounce(() => {
    setSettings((oldSettings) => ({
      ...oldSettings,
      borderSize: borderSize[0]
    }));
  }, 500);

  const setBorderColor = useDebounce(() => {
    console.log('setting border color', borderColor);
    setSettings((oldSettings) => ({
      ...oldSettings,
      borderColor: borderColor
    }));
  }, 500);

  useEffect(() => {
    setBorder();
  }, [borderSize]);

  useEffect(() => {
    setBorderColor();
  }, [borderColor]);

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
      <View className="flex flex-col h-1/2 w-full p-4">
        <View className="flex flex-col h-full w-full rounded-lg bg-zinc-800 p-2 pr-6">
          <View className="flex flex-row items-center my-2">
            <View className="flex flex-row items-center justify-center w-1/5">
              <MaterialIcons
                name="crop-square"
                size={24}
                style={{
                  color: '#bbb'
                }}
              />
            </View>
            <View className="relative flex w-4/5 justify-center">
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
          <View className="flex flex-row items-center my-2">
            <View className="flex flex-row items-center w-1/5 justify-center">
              <MaterialIcons
                name="aspect-ratio"
                size={24}
                style={{
                  color: '#bbb'
                }}
              />
            </View>
            <View className="relative flex flex-row w-4/5 justify-evenly ">
              {aspectRatios.map((aspectRatio) => (
                <View
                  key={aspectRatio}
                  className="bg-zinc-600 px-2 py-1 rounded-lg"
                >
                  <Text className="font-space text-zinc-200">
                    {aspectRatio}
                  </Text>
                </View>
              ))}
            </View>
          </View>
          <View className="flex flex-row items-center h-3/5">
            <View className="flex flex-row items-center w-1/5 justify-center">
              <MaterialIcons
                name="color-lens"
                size={24}
                style={{
                  color: '#bbb'
                }}
              />
            </View>
            <View className="flex flex-1 w-4/5 justify-center pt-2">
              <TriangleColorPicker
                style={{ flex: 1 }}
                color={borderColor}
                defaultColor={borderColor}
                hideControls
                onColorChange={(color) => {
                  setBorderColorState(fromHsv(color));
                }}
              />
            </View>
          </View>
        </View>
      </View>
    </PageContainer>
  );
}

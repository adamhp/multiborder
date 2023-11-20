import { ScrollView, View, Text, Pressable } from 'react-native';
import { useRecoilState, useRecoilValue } from 'recoil';
import { ImageThumbnailPost } from '../../components/ImageThumbnail';
import { ImagesScrollView } from '../../components/ImageScrollView';
import { imagesState, settingsState } from '../../lib/state';
import { PageContainer } from './_layout';
import { Slider } from '@miblanchard/react-native-slider';
import { useEffect, useState } from 'react';
import { useDebounce } from '../../lib/util';
import { FontAwesome } from '@expo/vector-icons';

import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { TriangleColorPicker, fromHsv } from 'react-native-color-picker';
import clsx from 'clsx';

type AspectRatio = {
  number: number;
  label: string | React.ReactNode;
};
const aspectRatios = [
  { number: -1, label: <MaterialIcons name="crop-original" size={20} /> },
  { number: 1, label: '1:1' },
  { number: 2 / 3, label: '2:3' },
  { number: 3 / 4, label: '3:4' },
  { number: 4 / 5, label: '4:5' }
];

export default function EditScreen() {
  const [settings, setSettings] = useRecoilState(settingsState);
  const images = useRecoilValue(imagesState);
  const [borderSize, setBorderSize] = useState([settings.borderSize]);
  const [aspectRatio, setAspectRatioState] = useState(
    settings.desiredAspectRatio
  );
  const [borderColor, setBorderColorState] = useState(settings.borderColor);

  const setBorder = useDebounce(() => {
    setSettings((oldSettings) => ({
      ...oldSettings,
      borderSize: borderSize[0]
    }));
  }, 100);

  const setBorderColor = useDebounce(() => {
    setSettings((oldSettings) => ({
      ...oldSettings,
      borderColor: borderColor
    }));
  }, 100);

  const setAspectRatio = useDebounce(() => {
    setSettings((oldSettings) => ({
      ...oldSettings,
      desiredAspectRatio: aspectRatio
    }));
  }, 100);

  useEffect(() => {
    setBorder();
  }, [borderSize]);

  useEffect(() => {
    setBorderColor();
  }, [borderColor]);

  useEffect(() => {
    setAspectRatio();
  }, [aspectRatio]);

  return (
    <PageContainer>
      <ImagesScrollView
        className="h-2/3"
        settings={settings}
        images={images}
        renderImage={(item) => (
          <View key={item.uri} className="mx-4">
            <ImageThumbnailPost borderSize={borderSize[0]} item={item} />
          </View>
        )}
      />
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
            <View className="relative flex flex-row items-center w-4/5 justify-evenly ">
              {aspectRatios.map((ar) => (
                <Pressable
                  key={String(ar.number.toFixed(2))}
                  onPress={() => {
                    setAspectRatioState(ar.number);
                  }}
                >
                  {({ pressed }) => (
                    <View
                      className={clsx(
                        {
                          'bg-zinc-700 border-amber-900 border-2':
                            ar.number === aspectRatio || pressed,
                          'bg-zinc-600': ar.number !== aspectRatio
                        },
                        'px-2 py-1 rounded-lg w-11 h-8 text-sm items-center justify-center'
                      )}
                    >
                      <Text className="font-space text-zinc-200">
                        {ar.label}
                      </Text>
                    </View>
                  )}
                </Pressable>
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

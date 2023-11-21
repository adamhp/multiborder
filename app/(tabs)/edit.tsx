import { Slider } from '@miblanchard/react-native-slider';
import { useEffect, useRef, useState } from 'react';
import {
  Animated,
  Dimensions,
  Pressable,
  Text,
  TextInput,
  View
} from 'react-native';
import { useRecoilState, useRecoilValue } from 'recoil';
import { ImagesScrollView } from '../../components/ImageScrollView';
import { ImageThumbnailPost } from '../../components/ImageThumbnail';
import { imagesState, settingsState } from '../../lib/state';
import { useDebounce } from '../../lib/util';
import { PageContainer } from './_layout';

import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import clsx from 'clsx';
import { TriangleColorPicker, fromHsv } from 'react-native-color-picker';

type AspectRatio = {
  number: number;
  label: string | React.ReactNode;
};

const aspectRatios: AspectRatio[] = [
  { number: -1, label: <MaterialIcons name="crop-original" size={20} /> },
  { number: 2 / 3, label: '2:3' },
  { number: 3 / 4, label: '3:4' },
  { number: 4 / 5, label: '4:5' },
  { number: 1, label: '1:1' }
];

const hex = /^#[0-9A-F]{6}$/i;
const hexShort = /^#[0-9A-F]{3}$/i;

export default function EditScreen() {
  const windowWidth = Dimensions.get('window').width;
  const windowHeight = Dimensions.get('window').height;
  const [settings, setSettings] = useRecoilState(settingsState);
  const images = useRecoilValue(imagesState);
  const [borderSize, setBorderSizeState] = useState([settings.borderSize]);
  const [aspectRatio, setAspectRatioState] = useState(
    settings.desiredAspectRatio
  );
  const [borderColor, setBorderColorState] = useState(settings.borderColor);
  const [colorFocused, setColorFocused] = useState(false);
  const [colorTextInput, setColorTextInput] = useState('');
  const translateYAnim = useRef(new Animated.Value(0)).current;
  const translateXAnim = useRef(new Animated.Value(0)).current;
  const scaleAnim = useRef(new Animated.Value(0)).current;

  const setBorderSize = useDebounce(() => {
    setSettings((oldSettings) => ({
      ...oldSettings,
      borderSize: borderSize[0]
    }));
  }, 100);

  const saveBorderSize = useDebounce(() => {
    AsyncStorage.setItem('borderSize', borderSize[0].toString());
  }, 2000);

  const setBorderColor = useDebounce(() => {
    setColorTextInput(borderColor);
    setSettings((oldSettings) => ({
      ...oldSettings,
      borderColor: borderColor
    }));
  }, 100);

  const saveBorderColor = useDebounce(() => {
    AsyncStorage.setItem('borderColor', borderColor);
  }, 2000);

  const setAspectRatio = useDebounce(() => {
    setSettings((oldSettings) => ({
      ...oldSettings,
      desiredAspectRatio: aspectRatio
    }));
  }, 100);

  const saveAspectRatio = useDebounce(() => {
    AsyncStorage.setItem('desiredAspectRatio', aspectRatio.toString());
  }, 2000);

  useEffect(() => {
    setBorderSize();
    saveBorderSize();
  }, [borderSize]);

  useEffect(() => {
    setBorderColor();
    saveBorderColor();
  }, [borderColor]);

  useEffect(() => {
    setAspectRatio();
    saveAspectRatio();
  }, [aspectRatio]);

  useEffect(() => {
    if (colorFocused) {
      Animated.timing(translateXAnim, {
        toValue: -windowWidth / 2 + 24,
        duration: 200,
        useNativeDriver: true
      }).start();
      Animated.timing(translateYAnim, {
        toValue: -windowHeight / 2,
        duration: 200,
        useNativeDriver: true
      }).start();
      Animated.timing(scaleAnim, {
        toValue: 1.5,
        duration: 200,
        useNativeDriver: true
      }).start();
    } else {
      Animated.timing(translateXAnim, {
        toValue: 0,
        duration: 200,
        useNativeDriver: true
      }).start();
      Animated.timing(translateYAnim, {
        toValue: 0,
        duration: 200,
        useNativeDriver: true
      }).start();
      Animated.timing(scaleAnim, {
        toValue: 1,
        duration: 100,
        useNativeDriver: true
      }).start();
    }
  }, [colorFocused]);

  return (
    <PageContainer>
      <ImagesScrollView
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
                onValueChange={setBorderSizeState}
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
          <View className="flex flex-row items-center h-3/5 relative">
            <View className="flex flex-row items-center w-1/5 justify-center">
              <MaterialIcons
                name="color-lens"
                size={24}
                style={{
                  color: '#bbb'
                }}
              />
            </View>
            <View className="flex flex-1 w-4/5 pt-2 pr-6">
              <TriangleColorPicker
                style={{ flex: 1 }}
                defaultColor={borderColor}
                hideControls
                onColorChange={(color) => {
                  setBorderColorState(fromHsv(color));
                }}
              />
              <Animated.View
                style={{
                  transform: [
                    {
                      translateX: translateXAnim
                    },
                    {
                      translateY: translateYAnim
                    },
                    { scale: scaleAnim }
                  ]
                }}
              >
                <TextInput
                  autoComplete="off"
                  caretHidden
                  clearTextOnFocus
                  inputMode="text"
                  maxLength={7}
                  defaultValue={borderColor}
                  className="text-center text-zinc-100 font-space bg-zinc-500 rounded-md text-xs h-8 w-20 p-2 -pb-2 -mb-3 absolute bottom-0 -right-10"
                  onFocus={() => {
                    setColorTextInput('#');
                    setColorFocused(true);
                    console.log('color focused');
                  }}
                  onBlur={() => {
                    setColorFocused(false);
                    console.log('color blurred');
                  }}
                  onSubmitEditing={(e) => {
                    let input = e.nativeEvent.text.startsWith('#')
                      ? e.nativeEvent.text
                      : '#' + e.nativeEvent.text;
                    if (hex.test(input) || hexShort.test(input)) {
                      setBorderColorState(input);
                    }
                  }}
                  value={colorTextInput}
                  onChangeText={(text) => {
                    setColorTextInput(text);
                  }}
                />
              </Animated.View>
            </View>
          </View>
        </View>
      </View>
    </PageContainer>
  );
}

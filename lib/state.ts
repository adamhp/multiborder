import AsyncStorage from '@react-native-async-storage/async-storage';
import { ImagePickerAsset } from 'expo-image-picker';
import { atom } from 'recoil';

export const imagesState = atom<ImagePickerAsset[]>({
  key: 'images',
  default: []
});

export const imagesPostState = atom<ImagePickerAsset[]>({
  key: 'imagesPost',
  default: []
});

export const captureFunctionsState = atom<Record<string, Function>>({
  key: 'captureFunctions',
  default: {}
});

export type Settings = {
  desiredAspectRatio: number;
  desiredSize: number;
  borderSize: number;
  borderColor: string;
};

export const defaultDesiredSize = 200;
export const defaultDesiredAspectRatio = 4 / 5;
export const defaultBorderSize = 5;
export const defaultBorderColor = '#fff';

export const loadSettings = async (): Promise<Settings> => {
  const desiredSize = defaultDesiredSize;
  const desiredAspectRatio = await AsyncStorage.getItem(
    'desiredAspectRatio'
  ).then((n) =>
    n !== null ? Number.parseFloat(n) : defaultDesiredAspectRatio
  );
  const borderSize = await AsyncStorage.getItem('borderSize').then((n) =>
    n !== null ? Number.parseFloat(n) : defaultBorderSize
  );
  const borderColor = await AsyncStorage.getItem('borderColor').then((s) =>
    s != null ? s : defaultBorderColor
  );
  return { desiredSize, desiredAspectRatio, borderSize, borderColor };
};

export const settingsState = atom<Settings>({
  key: 'settings',
  default: {
    desiredAspectRatio: defaultDesiredAspectRatio,
    desiredSize: defaultDesiredSize,
    borderSize: defaultBorderSize,
    borderColor: defaultBorderColor
  }
});

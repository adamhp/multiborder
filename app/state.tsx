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
};

export const settingsState = atom<Settings>({
  key: 'settings',
  default: {
    desiredAspectRatio: 4 / 5,
    desiredSize: 200,
    borderSize: 5
  }
});

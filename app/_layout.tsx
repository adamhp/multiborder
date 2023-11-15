import FontAwesome from '@expo/vector-icons/FontAwesome';
import { ThemeProvider } from '@react-navigation/native';
import { useFonts } from 'expo-font';
import * as Linking from 'expo-linking';
import { SplashScreen, Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { styled } from 'nativewind';
import { useEffect } from 'react';
import { Pressable, Text, View } from 'react-native';
import Toast, { BaseToast, ToastShowParams } from 'react-native-toast-message';
import { RecoilRoot } from 'recoil';

const StyledBaseToast = styled(BaseToast);

export {
  // Catch any errors thrown by the Layout component.
  ErrorBoundary
} from 'expo-router';

export const unstable_settings = {
  // Ensure that reloading on `/modal` keeps a back button present.
  initialRouteName: '(tabs)'
};

// Prevent the splash screen from auto-hiding before asset loading is complete.
SplashScreen.preventAutoHideAsync();

const toastConfig = {
  success: ({ text1, props }: ToastShowParams) => (
    <View className="w-[90vw] h-20 bg-zinc-700 p-4 rounded-lg shadow-lg flex flex-row justify-between items-center">
      <Text className="text-lg text-white">{text1}</Text>
      <Pressable
        onPress={() => {
          Linking.openURL(`photos-redirect://`);
        }}
        className="bg-zinc-900 w-24 rounded-lg px-3 py-2 flex flex-row items-center justify-between"
      >
        <Text className="text-lg text-white mr-1">View</Text>
        <FontAwesome name="eye" size={20} color="white" />
      </Pressable>
    </View>
  ),
  error: ({ text1, props }: ToastShowParams) => (
    <View className="w-[90vw] h-16 bg-zinc-700 p-4 rounded-lg shadow-lg flex-1 flex-row border-l-2 border-red-700">
      <Text className="text-lg text-white">{text1}</Text>
    </View>
  )
};

export default function RootLayout() {
  useEffect(() => {
    Toast.show({
      type: 'success',
      text1: `Saved x!`
    });
  }, []);
  const [loaded, error] = useFonts({
    SpaceMono: require('../assets/fonts/SpaceMono-Regular.ttf'),
    ...FontAwesome.font
  });

  // Expo Router uses Error Boundaries to catch errors in the navigation tree.
  useEffect(() => {
    if (error) throw error;
  }, [error]);

  useEffect(() => {
    if (loaded) {
      SplashScreen.hideAsync();
    }
  }, [loaded]);

  if (!loaded) {
    return null;
  }

  return <RootLayoutNav />;
}

const Theme = {
  dark: true,
  colors: {
    primary: '#f59e0b',
    background: '#18181b',
    card: '#18181b',
    text: '#f4f4f5',
    border: '#92400e',
    notification: '18181b'
  }
};

function RootLayoutNav() {
  return (
    <>
      <ThemeProvider value={Theme}>
        <RecoilRoot>
          <StatusBar style="light" />
          <Stack>
            <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
            <Stack.Screen
              name="modal"
              options={{ headerShown: false, presentation: 'modal' }}
            />
          </Stack>
        </RecoilRoot>
      </ThemeProvider>
      <Toast config={toastConfig} />
    </>
  );
}

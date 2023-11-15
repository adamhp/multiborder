import FontAwesome from '@expo/vector-icons/FontAwesome';
import { ThemeProvider } from '@react-navigation/native';
import { useFonts } from 'expo-font';
import { SplashScreen, Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { styled } from 'nativewind';
import { useEffect } from 'react';
import { Text, View } from 'react-native';
import Toast, {
  BaseToast,
  BaseToastProps,
  ErrorToast,
  ToastShowParams,
} from 'react-native-toast-message';
import { RecoilRoot } from 'recoil';

const StyledBaseToast = styled(BaseToast);

export {
  // Catch any errors thrown by the Layout component.
  ErrorBoundary,
} from 'expo-router';

export const unstable_settings = {
  // Ensure that reloading on `/modal` keeps a back button present.
  initialRouteName: '(tabs)',
};

// Prevent the splash screen from auto-hiding before asset loading is complete.
SplashScreen.preventAutoHideAsync();

const toastConfig = {
  success: (props: BaseToastProps) => (
    <StyledBaseToast {...props} className='bg-zinc-700 text-zinc-100' />
  ),
  /*
    Overwrite 'error' type,
    by modifying the existing `ErrorToast` component
  */
  error: (props: BaseToastProps) => (
    <ErrorToast
      {...props}
      text1Style={{
        fontSize: 17,
      }}
      text2Style={{
        fontSize: 15,
      }}
    />
  ),
  /*
    Or create a completely new type - `tomatoToast`,
    building the layout from scratch.

    I can consume any custom `props` I want.
    They will be passed when calling the `show` method (see below)
  */
  tomatoToast: ({ text1, props }: ToastShowParams) => (
    <View style={{ height: 60, width: '100%', backgroundColor: 'tomato' }}>
      <Text>{text1}</Text>
      <Text>{props.uuid}</Text>
    </View>
  ),
};

export default function RootLayout() {
  const [loaded, error] = useFonts({
    SpaceMono: require('../assets/fonts/SpaceMono-Regular.ttf'),
    ...FontAwesome.font,
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
    notification: '18181b',
  },
};

function RootLayoutNav() {
  return (
    <>
      <ThemeProvider value={Theme}>
        <RecoilRoot>
          <StatusBar style='light' />
          <Stack>
            <Stack.Screen name='(tabs)' options={{ headerShown: false }} />
            <Stack.Screen
              name='modal'
              options={{ headerShown: false, presentation: 'modal' }}
            />
          </Stack>
        </RecoilRoot>
      </ThemeProvider>
      <Toast />
    </>
  );
}

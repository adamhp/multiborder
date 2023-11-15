import { Link, Stack } from 'expo-router';
import { Text, View } from 'react-native';
import i18n from '../assets/locales';

export default function NotFoundScreen() {
  return (
    <>
      <Stack.Screen options={{ title: 'Oops!' }} />
      <View>
        <Link href="/">
          <Text>{i18n.t('home')}</Text>
        </Link>
      </View>
    </>
  );
}

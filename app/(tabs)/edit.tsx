import { StyleSheet, Text, View } from 'react-native';
import { PageContainer } from './_layout';
import i18n from '../../assets/locales';

export default function EditScreen() {
  return (
    <PageContainer>
      <Text>{i18n.t('settings')}</Text>
      <View />
    </PageContainer>
  );
}
